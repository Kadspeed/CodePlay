extends CharacterBody2D

## ============================================================
## ESQUELETO - Inimigo baseado em máquina de estados (enum)
## Godot 4.6 / GDScript
## ============================================================
##
## MUDANÇA NESTA VERSÃO: o AnimationPlayer foi REMOVIDO por completo.
## O som de passo usa um Timer simples (Timer_Passo) tocando em
## intervalo fixo enquanto ele anda, em vez de precisar de uma
## keyframe por passo.
##
## MUDANÇA NO ATAQUE: agora é a própria Area_Ataque que decide quando
## atacar, em vez de calcular distância dentro do CHASE. A Area_Ataque
## fica sempre ligada (monitoring = true); assim que o Player entra
## nela, o Esqueleto já reage na hora: toca a animação, o som, e
## aplica o dano — tudo junto, sem espera. Mesmo padrão do Cogumelo.
##
## ESTADO EXTRA "CHASE":
## Continua existindo pelo mesmo motivo de antes: patrulha (WALK) e
## perseguição (CHASE) têm lógicas de direção muito diferentes, e
## juntar as duas no mesmo estado exigiria ifs extras dentro do WALK.

## ------------------------------------------------------------
## ENUM DE ESTADOS
## ------------------------------------------------------------
enum Estado {
	IDLE,
	WALK,
	CHASE,
	ATTACK,
	TAKE_HIT,
	SHIELD,
	DEATH,
}

## ------------------------------------------------------------
## CONFIGURAÇÕES (tudo agrupado e exportado para o Inspector)
## ------------------------------------------------------------

@export_group("Movimento")
@export var velocidade_movimento: float = 60.0
@export var gravidade: float = 980.0

@export_group("Patrulha")
@export var patrulha_tempo: float = 4.0       # tempo andando em patrulha
@export var tempo_parado: float = 2.0         # tempo parado em patrulha

@export_group("Vida")
@export var vida_maxima: int = 15
@export var dano_ataque: int = 10             # dano que o Esqueleto causa no Player

@export_group("Detecção e Ataque")
@export var attack_cooldown_tempo: float = 1.5
@export var tempo_memoria_player: float = 3.0 # quanto tempo ele "lembra" do Player

@export_group("Shield (Defesa)")
@export_range(0.0, 1.0, 0.01) var chance_de_bloqueio: float = 0.6
@export var shield_duracao: float = 0.8       # duração da janela de defesa
@export var shield_intervalo: float = 2.0     # tempo mínimo entre defesas
@export var shield_invulneravel_duracao: float = 1.2  # por quanto tempo fica invulnerável ao ativar o Shield

@export_group("Áudio - Idle")
@export var som_idle_intervalo_min: float = 2.0
@export var som_idle_intervalo_max: float = 4.0

@export_group("Áudio - Volume")
@export var volume_extra_db: float = 6.0  # some esse valor ao volume atual de TODOS os sons do Esqueleto

@export_group("Áudio - Atraso")
@export var atraso_som_ataque: float = 1.0  # segundos entre a animação de Attack começar e o som tocar
@export var atraso_som_shield: float = 1.0  # segundos entre a animação de Shield começar e o som tocar

@export_group("Áudio - Passos")
@export var passo_intervalo: float = 0.4      # intervalo entre sons de passo ao andar/perseguir

@export_group("Morte")
@export var death_fade_duracao: float = 1.0   # tempo até o Esqueleto sumir de vez após a animação Death

@export_group("Pontuação")
@export var pontos_ao_morrer: int = 10


## ------------------------------------------------------------
## SINAIS
## ------------------------------------------------------------
## Emitido quando o Esqueleto morre. Futuramente, conecte este sinal
## a uma função do GameManager (ex: GameManager.adicionar_pontos)
## ou use a função _comunicar_morte_ao_game_manager() abaixo.
signal inimigo_morto(pontos: int)


## ------------------------------------------------------------
## REFERÊNCIAS DE NÓS (nomes exatamente como na cena)
## ------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D
@onready var raycast_chao: RayCast2D = $RayCast_Chao

@onready var area_deteccao: Area2D = $Area_Detecao
@onready var area_ataque: Area2D = $Area_Ataque

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var timer_patrulha: Timer = $Timer_Patrulha
@onready var timer_parado: Timer = $Timer_Parado
@onready var timer_som_idle: Timer = $Timer_Som_Idle

@onready var som_idle: AudioStreamPlayer2D = $Idle
@onready var som_walk: AudioStreamPlayer2D = $Walk
@onready var som_attack: AudioStreamPlayer2D = $Attack
@onready var som_take_hit: AudioStreamPlayer2D = $Take_hit
@onready var som_death: AudioStreamPlayer2D = $Death
@onready var som_shield: AudioStreamPlayer2D = $Shield

## Timer criado por código (não precisa existir na cena) para tocar o
## som de passo em intervalo fixo enquanto anda/persegue, substituindo
## o antigo "Walk_Passos" do AnimationPlayer.
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

var pode_bloquear: bool = true
var tempo_para_proximo_bloqueio: float = 0.0

# Invulnerabilidade temporária ao ativar o Shield. Decrementa a cada
# frame em _atualizar_cooldown_bloqueio(), igual ao padrão já usado
# para "tempo_para_proximo_bloqueio" — não depende de ids nem de
# await, então não corre risco de travar em "true".
var esta_invulneravel: bool = false
var tempo_invulneravel_restante: float = 0.0

# Memória do Player (última posição vista)
var perseguindo_memoria: bool = false
var ultima_posicao_conhecida: Vector2 = Vector2.ZERO
var tempo_memoria_restante: float = 0.0

# Offsets originais para virar RayCast e Area_Ataque junto com o sprite
var raycast_offset_x: float = 12.0
var area_ataque_offset_x: float = 0.0

# Contador usado para invalidar o "await" da janela de defesa (SHIELD)
# se o Esqueleto trocar de estado (ou morrer) antes dela terminar.
var _id_acao_atual: int = 0


## ==============================================================
## CICLO DE VIDA
## ==============================================================

func _ready() -> void:
	add_to_group("enemies")

	vida_atual = vida_maxima

	# Guarda o deslocamento horizontal original do RayCast_Chao e da
	# Area_Ataque para que possamos espelhá-los quando o Esqueleto virar.
	raycast_offset_x = absf(raycast_chao.position.x) if raycast_chao.position.x != 0.0 else 12.0
	area_ataque_offset_x = area_ataque.position.x

	# A Area_Ataque agora fica SEMPRE ligada (não é mais aberta/fechada
	# durante o golpe). Assim que o Player entra nela, o Esqueleto
	# ataca na hora — ver _on_area_ataque_body_entered().
	area_ataque.monitoring = true

	# Impede que Attack / Take_hit / Shield / Death fiquem "presas"
	# tocando em loop infinito (isso é o que fazia parecer que o
	# Esqueleto travava nessas animações).
	_configurar_animacoes_nao_looping()

	# Aumenta o volume de todos os sons do Esqueleto de uma vez, sem
	# precisar clicar em cada AudioStreamPlayer2D no editor.
	_aplicar_volume_extra()

	# Timer de passo, criado em código para não precisar adicionar
	# nenhum nó novo na cena.
	timer_passo = Timer.new()
	timer_passo.one_shot = false
	timer_passo.wait_time = passo_intervalo
	add_child(timer_passo)
	timer_passo.timeout.connect(_on_timer_passo_timeout)

	# Conexão dos sinais (feita 100% por código, não é necessário
	# conectar nada manualmente na aba "Node" do editor).
	area_deteccao.body_entered.connect(_on_area_deteccao_body_entered)
	area_deteccao.body_exited.connect(_on_area_deteccao_body_exited)
	area_ataque.body_entered.connect(_on_area_ataque_body_entered)

	attack_cooldown.one_shot = true
	timer_patrulha.one_shot = true
	timer_parado.one_shot = true
	timer_som_idle.one_shot = true

	attack_cooldown.timeout.connect(_on_attack_cooldown_timeout)
	timer_patrulha.timeout.connect(_on_timer_patrulha_timeout)
	timer_parado.timeout.connect(_on_timer_parado_timeout)
	timer_som_idle.timeout.connect(_on_timer_som_idle_timeout)

	sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

	_mudar_estado(Estado.IDLE)


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	_aplicar_gravidade(delta)
	_atualizar_cooldown_bloqueio(delta)

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
		Estado.SHIELD:
			_processar_shield(delta)
		Estado.DEATH:
			pass # movimento já foi zerado ao entrar em DEATH

	move_and_slide()


func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		velocity.y = 0.0


func _atualizar_cooldown_bloqueio(delta: float) -> void:
	if tempo_para_proximo_bloqueio > 0.0:
		tempo_para_proximo_bloqueio -= delta
		if tempo_para_proximo_bloqueio <= 0.0:
			pode_bloquear = true

	if tempo_invulneravel_restante > 0.0:
		tempo_invulneravel_restante -= delta
		if tempo_invulneravel_restante <= 0.0:
			esta_invulneravel = false


## ==============================================================
## MÁQUINA DE ESTADOS - TROCA DE ESTADO
## ==============================================================

func _mudar_estado(novo_estado: Estado) -> void:
	if esta_morto and novo_estado != Estado.DEATH:
		return

	# Invalida qualquer "await" pendente de um ataque anterior (ex: se
	# o Esqueleto levar dano e mudar pra TAKE_HIT no meio do golpe).
	_id_acao_atual += 1

	# Para os timers relacionados ao estado anterior antes de entrar
	# no novo, evitando timers "fantasmas" disparando depois que o
	# estado já mudou.
	timer_parado.stop()
	timer_patrulha.stop()
	timer_som_idle.stop()
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
		Estado.SHIELD:
			_entrar_shield()
		Estado.DEATH:
			_entrar_death()


## ==============================================================
## ESTADO: IDLE (parte da patrulha - parado)
## ==============================================================

func _entrar_idle() -> void:
	velocity.x = 0.0
	sprite.play("Idle")
	timer_parado.wait_time = tempo_parado
	timer_parado.start()
	_agendar_som_idle()

func _processar_idle(_delta: float) -> void:
	pass # comportamento é todo dirigido por timers/sinais

func _on_timer_parado_timeout() -> void:
	if estado_atual == Estado.IDLE and not jogador_detectado and not perseguindo_memoria:
		_mudar_estado(Estado.WALK)

func _agendar_som_idle() -> void:
	timer_som_idle.wait_time = randf_range(som_idle_intervalo_min, som_idle_intervalo_max)
	timer_som_idle.start()

func _on_timer_som_idle_timeout() -> void:
	if estado_atual == Estado.IDLE:
		som_idle.play()
		_agendar_som_idle()


## ==============================================================
## ESTADO: WALK (parte da patrulha - andando)
## ==============================================================

func _entrar_walk() -> void:
	sprite.play("Walk")
	timer_patrulha.wait_time = patrulha_tempo
	timer_patrulha.start()
	timer_passo.start()

func _processar_walk(_delta: float) -> void:
	# RayCast_Chao evita que o Esqueleto ande para fora da plataforma
	# durante a patrulha: se não houver chão à frente, ele vira e para.
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
## ESTADO: CHASE (perseguição - ver explicação no topo do arquivo)
## ==============================================================

func _entrar_chase() -> void:
	sprite.play("Walk") # reaproveita a animação de andar
	timer_passo.start()

func _processar_chase(delta: float) -> void:
	if jogador_detectado and player_alvo != null:
		_perseguir_posicao(player_alvo.global_position)
		# O ataque não é mais decidido por distância aqui — é a própria
		# Area_Ataque que dispara o ataque quando o Player entra nela
		# (ver _on_area_ataque_body_entered).

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
		# Não há alvo nem memória: por segurança, volta à patrulha.
		_mudar_estado(Estado.IDLE)

func _perseguir_posicao(alvo_pos: Vector2) -> void:
	var dir_x := signf(alvo_pos.x - global_position.x)
	if dir_x != 0.0:
		direcao = int(dir_x)
	_atualizar_orientacao()
	velocity.x = velocidade_movimento * direcao


## ==============================================================
## DETECÇÃO DO PLAYER (Area_Detecao)
## ==============================================================
## IMPORTANTE: o Player precisa estar no grupo "player"
## (Node > Groups > adicionar "player") para ser reconhecido aqui.

func _on_area_deteccao_body_entered(body: Node2D) -> void:
	if esta_morto:
		return
	if body.is_in_group("player"):
		player_alvo = body
		jogador_detectado = true
		perseguindo_memoria = false
		if estado_atual != Estado.ATTACK and estado_atual != Estado.TAKE_HIT and estado_atual != Estado.SHIELD:
			_mudar_estado(Estado.CHASE)

func _on_area_deteccao_body_exited(body: Node2D) -> void:
	if body == player_alvo:
		jogador_detectado = false
		ultima_posicao_conhecida = player_alvo.global_position
		tempo_memoria_restante = tempo_memoria_player
		perseguindo_memoria = true
		# O Esqueleto continua em CHASE, mas agora andando até a
		# última posição conhecida (ver _processar_chase).


## ==============================================================
## DETECÇÃO DE ATAQUE (Area_Ataque) — sem cálculo de distância
## ==============================================================
## Assim que o Player entra fisicamente na Area_Ataque, o Esqueleto
## ataca imediatamente: toca a animação, o som, E aplica o dano no
## mesmo instante. Não há mais espera nem sincronização por tempo.

func _on_area_ataque_body_entered(body: Node2D) -> void:
	if esta_morto or not pode_atacar:
		return
	if estado_atual == Estado.TAKE_HIT or estado_atual == Estado.SHIELD or estado_atual == Estado.DEATH:
		return
	if body.is_in_group("player"):
		_mudar_estado(Estado.ATTACK)

## Enquanto o Esqueleto está em cooldown, o Player pode continuar
## dentro da Area_Ataque sem que um novo "body_entered" seja disparado
## (o sinal só dispara na entrada, não continuamente). Por isso, ao
## terminar o cooldown, checamos se o Player ainda está lá dentro e
## atacamos de novo automaticamente.
func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true
	if esta_morto:
		return
	if estado_atual == Estado.ATTACK or estado_atual == Estado.TAKE_HIT or estado_atual == Estado.SHIELD:
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
	pass # o dano já foi aplicado ao entrar no estado; só espera a animação terminar

func _aplicar_dano_area_ataque() -> void:
	for corpo in area_ataque.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("tomar_dano"):
			corpo.tomar_dano(dano_ataque)


## ==============================================================
## RECEBER DANO / SHIELD / TAKE_HIT (chamado pelo player.gd)
## ==============================================================
## O player.gd já chama automaticamente "enemy.tomar_dano(dano_ataque)"
## quando o AttackArea dele encosta em um corpo do grupo "enemies".
## Por isso a função aqui precisa se chamar exatamente "tomar_dano".

func tomar_dano(quantidade: int, _posicao_jogador: Vector2 = Vector2.ZERO) -> void:
	if esta_morto or esta_invulneravel:
		return

	if pode_bloquear and randf() < chance_de_bloqueio:
		_mudar_estado(Estado.SHIELD)
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
	pass # sai deste estado quando a animação terminar (ver sinal abaixo)


## ==============================================================
## ESTADO: SHIELD
## ==============================================================

func _entrar_shield() -> void:
	velocity.x = 0.0
	sprite.play("Shield")
	_tocar_som_com_atraso(som_shield, atraso_som_shield)

	pode_bloquear = false
	tempo_para_proximo_bloqueio = shield_intervalo

	# Invulnerabilidade começa junto com o Shield e tem duração própria
	# (shield_invulneravel_duracao), independente de quando o estado
	# SHIELD termina.
	esta_invulneravel = true
	tempo_invulneravel_restante = shield_invulneravel_duracao

	# Janela de defesa com duração própria (shield_duracao), independente
	# da duração exata da animação.
	var id_acao := _id_acao_atual
	await get_tree().create_timer(shield_duracao).timeout

	if id_acao == _id_acao_atual and estado_atual == Estado.SHIELD and not esta_morto:
		if jogador_detectado:
			_mudar_estado(Estado.CHASE)
		else:
			_mudar_estado(Estado.IDLE)

func _processar_shield(_delta: float) -> void:
	pass


## ==============================================================
## ESTADO: DEATH
## ==============================================================

func _entrar_death() -> void:
	esta_morto = true
	pode_atacar = false
	jogador_detectado = false
	perseguindo_memoria = false
	velocity = Vector2.ZERO

	area_deteccao.monitoring = false
	area_ataque.monitoring = false
	colisao.set_deferred("disabled", true)

	sprite.play("Death") # não-loop, garantido por _configurar_animacoes_nao_looping
	som_death.play()

	_emitir_morte()
	_preparar_drop()

## Chamado pelo sinal animation_finished quando "Death" termina de
## tocar (uma vez só, já que não é loop). A partir daqui o corpo some
## aos poucos em vez de desaparecer de repente.
func _iniciar_fade_e_remover() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, death_fade_duracao)
	tween.tween_callback(queue_free)

## Sinal + ponto de integração com o GameManager (pontuação).
## Basta conectar este sinal a uma função do GameManager, por exemplo:
##   esqueleto.inimigo_morto.connect(GameManager.adicionar_pontos)
## Não é necessário mudar nada aqui quando o GameManager existir.
func _emitir_morte() -> void:
	inimigo_morto.emit(pontos_ao_morrer)

## Função preparada para o futuro sistema de drops de itens.
## Quando o sistema existir, gere os itens aqui.
func _preparar_drop() -> void:
	pass

## Função preparada para um futuro efeito visual de dano
## (ex: piscar de vermelho por alguns frames).
func _efeito_dano() -> void:
	pass


## ==============================================================
## SINAL COMUM: FIM DE ANIMAÇÃO (AnimatedSprite2D)
## ==============================================================

func _on_animated_sprite_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			if estado_atual == Estado.ATTACK:
				if jogador_detectado:
					_mudar_estado(Estado.CHASE)
				else:
					_mudar_estado(Estado.IDLE)
		"Take_hit":
			if estado_atual == Estado.TAKE_HIT:
				if jogador_detectado:
					_mudar_estado(Estado.CHASE)
				else:
					_mudar_estado(Estado.IDLE)
		"Death":
			if estado_atual == Estado.DEATH:
				_iniciar_fade_e_remover()


## ==============================================================
## ORIENTAÇÃO (virar sprite, RayCast e Area_Ataque juntos)
## ==============================================================

func _atualizar_orientacao() -> void:
	sprite.flip_h = direcao < 0
	raycast_chao.position.x = raycast_offset_x * direcao
	area_ataque.position.x = absf(area_ataque_offset_x) * direcao


## ==============================================================
## SOM DE PASSO (substitui o antigo "Walk_Passos" do AnimationPlayer)
## ==============================================================

func _on_timer_passo_timeout() -> void:
	if estado_atual == Estado.WALK or estado_atual == Estado.CHASE:
		som_walk.play()


## ==============================================================
## ANIMAÇÕES SEM LOOP (evita ficar "preso" em Attack/Take_hit/Shield/Death)
## ==============================================================
## Força por código que essas 4 animações não repitam sozinhas, sem
## depender de você lembrar de desmarcar "Loop" pra cada uma no editor.
## Idle e Walk continuam em loop normalmente.

func _configurar_animacoes_nao_looping() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	for nome_animacao in ["Attack", "Take_hit", "Shield", "Death"]:
		if frames.has_animation(nome_animacao):
			frames.set_animation_loop(nome_animacao, false)


## ==============================================================
## VOLUME DOS SONS
## ==============================================================
## Soma "volume_extra_db" ao volume atual de cada AudioStreamPlayer2D,
## em vez de sobrescrever — então se você já tiver ajustado algum no
## Inspector, esse ajuste continua valendo, só fica mais alto.

func _aplicar_volume_extra() -> void:
	for som in [som_idle, som_walk, som_attack, som_take_hit, som_death, som_shield]:
		som.volume_db += volume_extra_db

## Toca um som depois de "atraso" segundos, sem travar o resto do
## script (usa await, então a animação/dano/movimento continuam
## acontecendo normalmente enquanto isso). Não cancela o som mesmo
## que o estado já tenha mudado nesse meio-tempo — só não toca se o
## Esqueleto já estiver morto (pra evitar tocar som depois do fade).
func _tocar_som_com_atraso(som: AudioStreamPlayer2D, atraso: float) -> void:
	await get_tree().create_timer(atraso).timeout
	if esta_morto:
		return
	som.play()


## ==============================================================
## API PÚBLICA (mesmo padrão usado no Cogumelo, para manter os
## inimigos consistentes entre si e prontos para sistemas genéricos,
## como HUD de vida de boss ou IA que itere sobre o grupo "enemies")
## ==============================================================

func get_dano() -> int:
	return dano_ataque

func get_vida() -> int:
	return vida_atual

func is_morto() -> bool:
	return esta_morto
