extends CharacterBody2D

## ============================================================
## GOBLIN - Inimigo baseado em máquina de estados (enum)
## Godot 4.x / GDScript
## ============================================================
##
## Mesmas mecânicas do Esqueleto, adaptadas à cena do Goblin:
## - Patrulha (IDLE parado / WALK andando) com RayCast para não cair
## - Detecção do Player (AreaDeteccao) + perseguição (CHASE) com memória
## - Ataque disparado pela AreaAttack (sem cálculo de distância)
## - TAKE_HIT ao levar dano, DEATH com fade e sinal de pontuação
##
## DIFERENÇAS EM RELAÇÃO AO ESQUELETO:
## - Não tem Shield (o Goblin não possui essa animação nem som).
## - Não tem som de Idle (não há AudioStreamPlayer2D "Idle" na cena).
## - A animação "Run" é usada tanto na patrulha quanto na perseguição.
## - Os Timers de patrulha, de parada e de passo são criados por
##   código, então você só precisa do AttackCooldownTimer na cena.
## - O Marker2D não é usado por este script.

## ------------------------------------------------------------
## ENUM DE ESTADOS
## ------------------------------------------------------------
enum Estado {
	IDLE,
	WALK,
	CHASE,
	ATTACK,
	TAKE_HIT,
	DEATH,
}

## ------------------------------------------------------------
## CONFIGURAÇÕES (agrupadas e exportadas para o Inspector)
## ------------------------------------------------------------

@export_group("Movimento")
@export var velocidade_movimento: float = 70.0
@export var gravidade: float = 980.0

@export_group("Patrulha")
@export var patrulha_tempo: float = 4.0       # tempo andando em patrulha
@export var tempo_parado: float = 2.0         # tempo parado em patrulha

@export_group("Vida")
@export var vida_maxima: int = 20
@export var dano_ataque: int = 8              # dano que o Goblin causa no Player

@export_group("Detecção e Ataque")
@export var attack_cooldown_tempo: float = 1.2
@export var tempo_memoria_player: float = 3.0 # quanto tempo ele "lembra" do Player

@export_group("Áudio - Volume")
@export var volume_extra_db: float = 6.0      # somado ao volume atual de TODOS os sons

@export_group("Áudio - Atraso")
@export var atraso_som_ataque: float = 0.0    # segundos entre o início do ataque e o som

@export_group("Áudio - Passos")
@export var passo_intervalo: float = 0.35     # intervalo entre sons de passo ao correr

@export_group("Morte")
@export var death_fade_duracao: float = 1.0   # tempo até sumir após a animação Death

@export_group("Pontuação")
@export var pontos_ao_morrer: int = 8


## ------------------------------------------------------------
## SINAIS
## ------------------------------------------------------------
## Emitido quando o Goblin morre. Conecte a uma função do GameManager:
##   goblin.inimigo_morto.connect(GameManager.adicionar_pontos)
signal inimigo_morto(pontos: int)


## ------------------------------------------------------------
## REFERÊNCIAS DE NÓS (nomes exatamente como na cena)
## ------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D
@onready var raycast_chao: RayCast2D = $FloorRayCast

@onready var area_deteccao: Area2D = $AreaDeteccao
@onready var area_ataque: Area2D = $AreaAttack

@onready var attack_cooldown: Timer = $AttackCooldownTimer

@onready var som_attack: AudioStreamPlayer2D = $Attack
@onready var som_run: AudioStreamPlayer2D = $Run
@onready var som_take_hit: AudioStreamPlayer2D = $Take_hit
@onready var som_death: AudioStreamPlayer2D = $Death

## Timers criados por código (não precisam existir na cena)
var timer_patrulha: Timer
var timer_parado: Timer
var timer_passo: Timer


## ------------------------------------------------------------
## VARIÁVEIS INTERNAS DE ESTADO
## ------------------------------------------------------------
var estado_atual: Estado = Estado.IDLE

var vida_atual: int
var esta_morto: bool = false

var direcao: int = 1  # 1 = direita | -1 = esquerda

var player_alvo: Node2D = null
var jogador_detectado: bool = false

var pode_atacar: bool = true

# Memória do Player (última posição vista)
var perseguindo_memoria: bool = false
var ultima_posicao_conhecida: Vector2 = Vector2.ZERO
var tempo_memoria_restante: float = 0.0

# Offsets originais para virar RayCast e AreaAttack junto com o sprite
var raycast_offset_x: float = 12.0
var area_ataque_offset_x: float = 0.0

# Contador usado para invalidar "awaits" pendentes ao trocar de estado
var _id_acao_atual: int = 0


## ==============================================================
## CICLO DE VIDA
## ==============================================================

func _ready() -> void:
	add_to_group("enemies")

	vida_atual = vida_maxima

	raycast_offset_x = absf(raycast_chao.position.x) if raycast_chao.position.x != 0.0 else 12.0
	area_ataque_offset_x = area_ataque.position.x

	# A AreaAttack fica SEMPRE ligada: quando o Player entra nela,
	# o Goblin ataca na hora (ver _on_area_ataque_body_entered).
	area_ataque.monitoring = true

	_configurar_animacoes_nao_looping()
	_aplicar_volume_extra()

	# Timers criados em código
	timer_patrulha = _criar_timer(true)
	timer_parado = _criar_timer(true)
	timer_passo = _criar_timer(false)
	timer_passo.wait_time = passo_intervalo

	timer_patrulha.timeout.connect(_on_timer_patrulha_timeout)
	timer_parado.timeout.connect(_on_timer_parado_timeout)
	timer_passo.timeout.connect(_on_timer_passo_timeout)

	attack_cooldown.one_shot = true
	attack_cooldown.timeout.connect(_on_attack_cooldown_timeout)

	# Sinais conectados 100% por código
	area_deteccao.body_entered.connect(_on_area_deteccao_body_entered)
	area_deteccao.body_exited.connect(_on_area_deteccao_body_exited)
	area_ataque.body_entered.connect(_on_area_ataque_body_entered)

	sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

	_mudar_estado(Estado.IDLE)


func _criar_timer(one_shot: bool) -> Timer:
	var t := Timer.new()
	t.one_shot = one_shot
	add_child(t)
	return t


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	_aplicar_gravidade(delta)

	match estado_atual:
		Estado.IDLE:
			_processar_idle(delta)
		Estado.WALK:
			_processar_walk(delta)
		Estado.CHASE:
			_processar_chase(delta)
		Estado.ATTACK:
			_processar_attack(delta)
		Estado.TAKE_HIT:
			_processar_take_hit(delta)
		Estado.DEATH:
			pass # movimento já foi zerado ao entrar em DEATH

	move_and_slide()


func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0


## ==============================================================
## MÁQUINA DE ESTADOS - TROCA DE ESTADO
## ==============================================================

func _mudar_estado(novo_estado: Estado) -> void:
	if esta_morto and novo_estado != Estado.DEATH:
		return

	# Invalida qualquer "await" pendente do estado anterior
	_id_acao_atual += 1

	# Para os timers do estado anterior
	timer_parado.stop()
	timer_patrulha.stop()
	timer_passo.stop()

	estado_atual = novo_estado

	match novo_estado:
		Estado.IDLE:
			_entrar_idle()
		Estado.WALK:
			_entrar_walk()
		Estado.CHASE:
			_entrar_chase()
		Estado.ATTACK:
			_entrar_attack()
		Estado.TAKE_HIT:
			_entrar_take_hit()
		Estado.DEATH:
			_entrar_death()


## ==============================================================
## ESTADO: IDLE (patrulha - parado)
## ==============================================================

func _entrar_idle() -> void:
	velocity.x = 0.0
	sprite.play("Idle")
	timer_parado.wait_time = tempo_parado
	timer_parado.start()

func _processar_idle(_delta: float) -> void:
	pass # comportamento dirigido por timers/sinais

func _on_timer_parado_timeout() -> void:
	if estado_atual == Estado.IDLE and not jogador_detectado and not perseguindo_memoria:
		_mudar_estado(Estado.WALK)


## ==============================================================
## ESTADO: WALK (patrulha - andando, usa a animação "Run")
## ==============================================================

func _entrar_walk() -> void:
	sprite.play("Run")
	timer_patrulha.wait_time = patrulha_tempo
	timer_patrulha.start()
	timer_passo.start()

func _processar_walk(_delta: float) -> void:
	# Se não houver chão à frente, vira e para
	if raycast_chao.enabled and not raycast_chao.is_colliding():
		direcao *= -1
		_atualizar_orientacao()
		_mudar_estado(Estado.IDLE)
		return

	velocity.x = velocidade_movimento * direcao
	_atualizar_orientacao()

func _on_timer_patrulha_timeout() -> void:
	if estado_atual == Estado.WALK and not jogador_detectado and not perseguindo_memoria:
		direcao *= -1
		_atualizar_orientacao()
		_mudar_estado(Estado.IDLE)


## ==============================================================
## ESTADO: CHASE (perseguição)
## ==============================================================

func _entrar_chase() -> void:
	sprite.play("Run") # reaproveita a animação de correr
	timer_passo.start()

func _processar_chase(delta: float) -> void:
	if jogador_detectado and player_alvo != null:
		_perseguir_posicao(player_alvo.global_position)

	elif perseguindo_memoria:
		tempo_memoria_restante -= delta
		var chegou_no_local := global_position.distance_to(ultima_posicao_conhecida) < 8.0

		if tempo_memoria_restante <= 0.0 or chegou_no_local:
			perseguindo_memoria = false
			player_alvo = null
			_mudar_estado(Estado.IDLE) # volta para a patrulha
		else:
			_perseguir_posicao(ultima_posicao_conhecida)

	else:
		_mudar_estado(Estado.IDLE)

func _perseguir_posicao(alvo_pos: Vector2) -> void:
	var dir_x := signf(alvo_pos.x - global_position.x)
	if dir_x != 0.0:
		direcao = int(dir_x)
	_atualizar_orientacao()
	velocity.x = velocidade_movimento * direcao


## ==============================================================
## DETECÇÃO DO PLAYER (AreaDeteccao)
## ==============================================================
## IMPORTANTE: o Player precisa estar no grupo "player".

func _on_area_deteccao_body_entered(body: Node2D) -> void:
	if esta_morto:
		return
	if body.is_in_group("player"):
		player_alvo = body
		jogador_detectado = true
		perseguindo_memoria = false
		if estado_atual != Estado.ATTACK and estado_atual != Estado.TAKE_HIT:
			_mudar_estado(Estado.CHASE)

func _on_area_deteccao_body_exited(body: Node2D) -> void:
	if body == player_alvo:
		jogador_detectado = false
		ultima_posicao_conhecida = player_alvo.global_position
		tempo_memoria_restante = tempo_memoria_player
		perseguindo_memoria = true
		# Continua em CHASE, agora indo até a última posição conhecida


## ==============================================================
## DETECÇÃO DE ATAQUE (AreaAttack)
## ==============================================================

func _on_area_ataque_body_entered(body: Node2D) -> void:
	if esta_morto or not pode_atacar:
		return
	if estado_atual == Estado.TAKE_HIT or estado_atual == Estado.DEATH:
		return
	if body.is_in_group("player"):
		_mudar_estado(Estado.ATTACK)

## Se o Player continuar dentro da AreaAttack durante o cooldown, o
## sinal body_entered não dispara de novo. Ao fim do cooldown,
## checamos se ele ainda está lá e atacamos outra vez.
func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true
	if esta_morto:
		return
	if estado_atual == Estado.ATTACK or estado_atual == Estado.TAKE_HIT:
		return
	if _jogador_esta_na_area_ataque():
		_mudar_estado(Estado.ATTACK)

func _jogador_esta_na_area_ataque() -> bool:
	for corpo in area_ataque.get_overlapping_bodies():
		if corpo.is_in_group("player"):
			return true
	return false


## ==============================================================
## ESTADO: ATTACK
## ==============================================================

func _entrar_attack() -> void:
	velocity.x = 0.0
	pode_atacar = false

	sprite.play("Attack")

	attack_cooldown.wait_time = attack_cooldown_tempo
	attack_cooldown.start()

	_aplicar_dano_area_ataque()
	_tocar_som_com_atraso(som_attack, atraso_som_ataque)

func _processar_attack(_delta: float) -> void:
	pass # dano já aplicado ao entrar; só espera a animação terminar

func _aplicar_dano_area_ataque() -> void:
	for corpo in area_ataque.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("tomar_dano"):
			corpo.tomar_dano(dano_ataque)


## ==============================================================
## RECEBER DANO / TAKE_HIT (chamado pelo player.gd)
## ==============================================================
## O player.gd chama "enemy.tomar_dano(dano_ataque)" quando o
## AttackArea dele encosta em um corpo do grupo "enemies".

func tomar_dano(quantidade: int, _posicao_jogador: Vector2 = Vector2.ZERO) -> void:
	if esta_morto:
		return

	vida_atual -= quantidade
	_efeito_dano()

	if vida_atual <= 0:
		vida_atual = 0
		_mudar_estado(Estado.DEATH)
	else:
		_mudar_estado(Estado.TAKE_HIT)


## ==============================================================
## ESTADO: TAKE_HIT
## ==============================================================

func _entrar_take_hit() -> void:
	velocity.x = 0.0
	sprite.play("Take_hit")
	som_take_hit.play()

func _processar_take_hit(_delta: float) -> void:
	pass # sai deste estado quando a animação terminar


## ==============================================================
## ESTADO: DEATH
## ==============================================================

func _entrar_death() -> void:
	esta_morto = true
	pode_atacar = false
	jogador_detectado = false
	perseguindo_memoria = false
	velocity = Vector2.ZERO

	area_deteccao.set_deferred("monitoring", false)
	area_ataque.set_deferred("monitoring", false)
	colisao.set_deferred("disabled", true)

	sprite.play("Death")
	som_death.play()

	_emitir_morte()
	_preparar_drop()

## Chamado quando a animação "Death" termina: o corpo some aos poucos.
func _iniciar_fade_e_remover() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, death_fade_duracao)
	tween.tween_callback(queue_free)

func _emitir_morte() -> void:
	inimigo_morto.emit(pontos_ao_morrer)

## Preparada para o futuro sistema de drops de itens.
func _preparar_drop() -> void:
	pass

## Preparada para um futuro efeito visual de dano (piscar vermelho).
func _efeito_dano() -> void:
	pass


## ==============================================================
## SINAL COMUM: FIM DE ANIMAÇÃO (AnimatedSprite2D)
## ==============================================================

func _on_animated_sprite_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			if estado_atual == Estado.ATTACK:
				_voltar_para_chase_ou_idle()
		"Take_hit":
			if estado_atual == Estado.TAKE_HIT:
				_voltar_para_chase_ou_idle()
		"Death":
			if estado_atual == Estado.DEATH:
				_iniciar_fade_e_remover()

func _voltar_para_chase_ou_idle() -> void:
	if jogador_detectado:
		_mudar_estado(Estado.CHASE)
	else:
		_mudar_estado(Estado.IDLE)


## ==============================================================
## ORIENTAÇÃO (vira sprite, RayCast e AreaAttack juntos)
## ==============================================================
## OBS: se o sprite original do Goblin olhar para a ESQUERDA,
## troque para "sprite.flip_h = direcao > 0".

func _atualizar_orientacao() -> void:
	sprite.flip_h = direcao < 0
	raycast_chao.position.x = raycast_offset_x * direcao
	area_ataque.position.x = absf(area_ataque_offset_x) * direcao


## ==============================================================
## SOM DE PASSO (Timer simples, sem AnimationPlayer)
## ==============================================================

func _on_timer_passo_timeout() -> void:
	if estado_atual == Estado.WALK or estado_atual == Estado.CHASE:
		som_run.play()


## ==============================================================
## ANIMAÇÕES SEM LOOP (evita ficar "preso" em Attack/Take_hit/Death)
## ==============================================================

func _configurar_animacoes_nao_looping() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	for nome_animacao in ["Attack", "Take_hit", "Death"]:
		if frames.has_animation(nome_animacao):
			frames.set_animation_loop(nome_animacao, false)


## ==============================================================
## VOLUME DOS SONS
## ==============================================================
## Soma "volume_extra_db" ao volume atual de cada AudioStreamPlayer2D.

func _aplicar_volume_extra() -> void:
	for som in [som_attack, som_run, som_take_hit, som_death]:
		som.volume_db += volume_extra_db

## Toca um som depois de "atraso" segundos, sem travar o resto do
## script. Se atraso <= 0, toca imediatamente. Não toca se o Goblin
## já estiver morto quando o atraso terminar.
func _tocar_som_com_atraso(som: AudioStreamPlayer2D, atraso: float) -> void:
	if atraso <= 0.0:
		som.play()
		return
	await get_tree().create_timer(atraso).timeout
	if esta_morto:
		return
	som.play()


## ==============================================================
## API PÚBLICA (mesmo padrão do Esqueleto e do Cogumelo)
## ==============================================================

func get_dano() -> int:
	return dano_ataque

func get_vida() -> int:
	return vida_atual

func is_morto() -> bool:
	return esta_morto
