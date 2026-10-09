extends CharacterBody2D

## ============================================================
## RATO - Inimigo baseado em máquina de estados (enum)
## Godot 4.x / GDScript
## ============================================================
##
## Mesmo padrão do Goblin, adaptado à cena do Rato:
## - Patrulha (animação "Walk") com FloorRayCast para não cair
## - Detecção do Player (AreaDeteccao) + perseguição com memória
## - Ataque disparado pela AreaAttack, com tempo de recarga
## - HURT ao levar dano e DEATH com remoção da cena ao fim da animação
##
## DIFERENÇAS EM RELAÇÃO AO GOBLIN:
## - Não há animação Idle: a patrulha usa apenas "Walk".
## - Não há nós de áudio na cena, então nenhum som é usado.
## - O Timer da cena ($Timer) é usado como recarga do ataque.
## - O Marker2D não é usado por este script.
## - A morte remove o inimigo logo após a animação "Death" (sem fade).
##
## Animações usadas (as únicas existentes): Walk, Attack, Hurt, Death.

## ------------------------------------------------------------
## ENUM DE ESTADOS
## ------------------------------------------------------------
enum Estado {
	PATRULHA,
	PERSEGUICAO,
	ATAQUE,
	DANO,
	MORTE,
}

## ------------------------------------------------------------
## CONFIGURAÇÕES (agrupadas e exportadas para o Inspector)
## ------------------------------------------------------------

@export_group("Movimento")
@export var velocidade_patrulha: float = 40.0
@export var velocidade_perseguicao: float = 70.0
@export var gravidade: float = 980.0

@export_group("Sprite")
## Marque se o sprite original do Rato olha para a DIREITA.
## Se ele olhar para a esquerda, desmarque.
@export var sprite_olha_para_direita: bool = true

@export_group("Vida")
@export var vida_maxima: int = 10
@export var dano_ataque: int = 5

@export_group("Detecção e Ataque")
@export var attack_cooldown_tempo: float = 1.0
@export var tempo_memoria_player: float = 3.0

@export_group("Pontuação")
@export var pontos_ao_morrer: int = 5


## ------------------------------------------------------------
## SINAIS
## ------------------------------------------------------------
## Emitido quando o Rato morre. Exemplo de conexão:
##   rato.inimigo_morto.connect(GameManager.adicionar_pontos)
signal inimigo_morto(pontos: int)


## ------------------------------------------------------------
## REFERÊNCIAS DE NÓS (nomes exatamente como na cena)
## ------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D
@onready var raycast_chao: RayCast2D = $FloorRayCast

@onready var area_deteccao: Area2D = $AreaDeteccao
@onready var area_ataque: Area2D = $AreaAttack

## Timer existente na cena: usado como recarga do ataque
@onready var attack_cooldown: Timer = $Timer


## ------------------------------------------------------------
## VARIÁVEIS INTERNAS DE ESTADO
## ------------------------------------------------------------
var estado_atual: Estado = Estado.PATRULHA

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


## ==============================================================
## CICLO DE VIDA
## ==============================================================

func _ready() -> void:
	add_to_group("enemies")

	vida_atual = vida_maxima

	raycast_chao.enabled = true
	raycast_offset_x = absf(raycast_chao.position.x) if raycast_chao.position.x != 0.0 else 12.0
	area_ataque_offset_x = area_ataque.position.x

	# A AreaAttack fica SEMPRE ligada: quando o Player entra nela,
	# o Rato ataca na hora (ver _on_area_ataque_body_entered).
	area_ataque.monitoring = true
	area_deteccao.monitoring = true

	_configurar_animacoes()

	# Timer da cena (recarga do ataque)
	attack_cooldown.one_shot = true
	attack_cooldown.autostart = false
	attack_cooldown.stop()

	# Sinais conectados por código, sem duplicar conexões
	# (caso já tenham sido ligados pelo editor)
	_conectar_sinal(attack_cooldown.timeout, _on_attack_cooldown_timeout)
	_conectar_sinal(area_deteccao.body_entered, _on_area_deteccao_body_entered)
	_conectar_sinal(area_deteccao.body_exited, _on_area_deteccao_body_exited)
	_conectar_sinal(area_ataque.body_entered, _on_area_ataque_body_entered)
	_conectar_sinal(sprite.animation_finished, _on_animated_sprite_animation_finished)

	_mudar_estado(Estado.PATRULHA)


## Conecta um sinal apenas se ainda não estiver conectado.
func _conectar_sinal(sinal: Signal, funcao: Callable) -> void:
	if not sinal.is_connected(funcao):
		sinal.connect(funcao)


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	_aplicar_gravidade(delta)

	match estado_atual:
		Estado.PATRULHA:
			_processar_patrulha(delta)
		Estado.PERSEGUICAO:
			_processar_perseguicao(delta)
		Estado.ATAQUE:
			_processar_ataque(delta)
		Estado.DANO:
			_processar_dano(delta)
		Estado.MORTE:
			pass # movimento já foi zerado ao entrar em MORTE

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
	# Depois de morto, nenhum outro estado pode ser ativado
	if esta_morto and novo_estado != Estado.MORTE:
		return

	estado_atual = novo_estado

	match novo_estado:
		Estado.PATRULHA:
			_entrar_patrulha()
		Estado.PERSEGUICAO:
			_entrar_perseguicao()
		Estado.ATAQUE:
			_entrar_ataque()
		Estado.DANO:
			_entrar_dano()
		Estado.MORTE:
			_entrar_morte()


## ==============================================================
## ESTADO: PATRULHA (anda com "Walk")
## ==============================================================

func _entrar_patrulha() -> void:
	sprite.play("Walk")
	_atualizar_orientacao()

func _processar_patrulha(_delta: float) -> void:
	# Parede à frente ou sem chão à frente: vira para o outro lado
	var sem_chao_a_frente: bool = is_on_floor() and raycast_chao.enabled and not raycast_chao.is_colliding()
	if is_on_wall() or sem_chao_a_frente:
		direcao *= -1
		_atualizar_orientacao()

	velocity.x = velocidade_patrulha * direcao


## ==============================================================
## ESTADO: PERSEGUICAO
## ==============================================================

func _entrar_perseguicao() -> void:
	sprite.play("Walk") # o Rato só tem "Walk" para se mover

func _processar_perseguicao(delta: float) -> void:
	if jogador_detectado and is_instance_valid(player_alvo):
		_perseguir_posicao(player_alvo.global_position)

	elif perseguindo_memoria:
		tempo_memoria_restante -= delta
		var chegou_no_local: bool = global_position.distance_to(ultima_posicao_conhecida) < 8.0

		if tempo_memoria_restante <= 0.0 or chegou_no_local:
			perseguindo_memoria = false
			player_alvo = null
			velocity.x = 0.0
			_mudar_estado(Estado.PATRULHA) # volta para a patrulha
		else:
			_perseguir_posicao(ultima_posicao_conhecida)

	else:
		player_alvo = null
		jogador_detectado = false
		_mudar_estado(Estado.PATRULHA)

func _perseguir_posicao(alvo_pos: Vector2) -> void:
	var dir_x: float = signf(alvo_pos.x - global_position.x)
	if dir_x != 0.0:
		direcao = int(dir_x)
	_atualizar_orientacao()

	# Para ao chegar na borda (não cai) e enquanto espera a recarga
	# com o Player já dentro da AreaAttack.
	var sem_chao_a_frente: bool = is_on_floor() and raycast_chao.enabled and not raycast_chao.is_colliding()
	if sem_chao_a_frente or (not pode_atacar and _jogador_esta_na_area_ataque()):
		velocity.x = 0.0
	else:
		velocity.x = velocidade_perseguicao * direcao


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
		if estado_atual == Estado.PATRULHA:
			_mudar_estado(Estado.PERSEGUICAO)
		# Em ATAQUE/DANO o estado não é interrompido: ao terminar a
		# animação, _voltar_para_perseguicao_ou_patrulha() decide.

func _on_area_deteccao_body_exited(body: Node2D) -> void:
	if esta_morto:
		return
	if body == player_alvo:
		jogador_detectado = false
		ultima_posicao_conhecida = body.global_position
		tempo_memoria_restante = tempo_memoria_player
		perseguindo_memoria = true
		# Continua em PERSEGUICAO, agora indo até a última posição conhecida


## ==============================================================
## DETECÇÃO DE ATAQUE (AreaAttack)
## ==============================================================

func _on_area_ataque_body_entered(body: Node2D) -> void:
	if esta_morto or not pode_atacar:
		return
	if estado_atual == Estado.DANO or estado_atual == Estado.ATAQUE or estado_atual == Estado.MORTE:
		return
	if body.is_in_group("player"):
		_mudar_estado(Estado.ATAQUE)

## Se o Player continuar dentro da AreaAttack durante a recarga, o
## sinal body_entered não dispara de novo. Ao fim da recarga,
## checamos se ele ainda está lá e atacamos outra vez.
func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true
	if esta_morto:
		return
	if estado_atual == Estado.ATAQUE or estado_atual == Estado.DANO:
		return # ao terminar a animação, a checagem é refeita
	if _jogador_esta_na_area_ataque():
		_mudar_estado(Estado.ATAQUE)

func _jogador_esta_na_area_ataque() -> bool:
	for corpo in area_ataque.get_overlapping_bodies():
		if corpo.is_in_group("player"):
			return true
	return false


## ==============================================================
## ESTADO: ATAQUE
## ==============================================================

func _entrar_ataque() -> void:
	velocity.x = 0.0
	pode_atacar = false

	# Vira para o Player antes de atacar
	if is_instance_valid(player_alvo):
		var dir_x: float = signf(player_alvo.global_position.x - global_position.x)
		if dir_x != 0.0:
			direcao = int(dir_x)
			_atualizar_orientacao()

	sprite.play("Attack")

	attack_cooldown.wait_time = attack_cooldown_tempo
	attack_cooldown.start()

	_aplicar_dano_area_ataque()

func _processar_ataque(_delta: float) -> void:
	velocity.x = 0.0 # dano já aplicado ao entrar; só espera a animação terminar

func _aplicar_dano_area_ataque() -> void:
	for corpo in area_ataque.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("tomar_dano"):
			corpo.tomar_dano(dano_ataque)


## ==============================================================
## RECEBER DANO (chamado pelo player.gd)
## ==============================================================
## O player.gd chama "enemy.tomar_dano(dano_ataque)" quando a área
## de ataque dele encosta em um corpo do grupo "enemies".

func tomar_dano(quantidade: int, _posicao_jogador: Vector2 = Vector2.ZERO) -> void:
	if esta_morto:
		return

	vida_atual -= quantidade

	if vida_atual <= 0:
		vida_atual = 0
		_mudar_estado(Estado.MORTE)
	else:
		_mudar_estado(Estado.DANO)


## ==============================================================
## ESTADO: DANO (animação "Hurt")
## ==============================================================

func _entrar_dano() -> void:
	velocity.x = 0.0
	sprite.play("Hurt")

func _processar_dano(_delta: float) -> void:
	velocity.x = 0.0 # sai deste estado quando a animação terminar


## ==============================================================
## ESTADO: MORTE (animação "Death")
## ==============================================================

func _entrar_morte() -> void:
	esta_morto = true
	pode_atacar = false
	jogador_detectado = false
	perseguindo_memoria = false
	player_alvo = null
	velocity = Vector2.ZERO

	attack_cooldown.stop()

	# set_deferred evita erro de "flushing queries" ao mexer em
	# colisões durante um callback de física/sinal.
	area_deteccao.set_deferred("monitoring", false)
	area_ataque.set_deferred("monitoring", false)
	colisao.set_deferred("disabled", true)

	sprite.play("Death")

	inimigo_morto.emit(pontos_ao_morrer)


## ==============================================================
## SINAL COMUM: FIM DE ANIMAÇÃO (AnimatedSprite2D)
## ==============================================================

func _on_animated_sprite_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			if estado_atual == Estado.ATAQUE:
				_voltar_para_perseguicao_ou_patrulha()
		"Hurt":
			if estado_atual == Estado.DANO:
				_voltar_para_perseguicao_ou_patrulha()
		"Death":
			if estado_atual == Estado.MORTE:
				queue_free()

func _voltar_para_perseguicao_ou_patrulha() -> void:
	# Se o Player ainda está na área de ataque e a recarga acabou, ataca de novo
	if pode_atacar and _jogador_esta_na_area_ataque():
		_mudar_estado(Estado.ATAQUE)
	elif jogador_detectado or perseguindo_memoria:
		_mudar_estado(Estado.PERSEGUICAO)
	else:
		_mudar_estado(Estado.PATRULHA)


## ==============================================================
## ORIENTAÇÃO (vira sprite, RayCast e AreaAttack juntos)
## ==============================================================

func _atualizar_orientacao() -> void:
	if sprite_olha_para_direita:
		sprite.flip_h = direcao < 0
	else:
		sprite.flip_h = direcao > 0

	raycast_chao.position.x = raycast_offset_x * direcao
	raycast_chao.force_raycast_update() # evita ler o resultado do lado antigo
	area_ataque.position.x = absf(area_ataque_offset_x) * direcao


## ==============================================================
## ANIMAÇÕES (loop)
## ==============================================================
## Walk em loop; Attack, Hurt e Death sem loop.

func _configurar_animacoes() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return

	if frames.has_animation("Walk"):
		frames.set_animation_loop("Walk", true)

	for nome_animacao in ["Attack", "Hurt", "Death"]:
		if frames.has_animation(nome_animacao):
			frames.set_animation_loop(nome_animacao, false)


## ==============================================================
## API PÚBLICA (mesmo padrão do Goblin)
## ==============================================================

func get_dano() -> int:
	return dano_ataque

func get_vida() -> int:
	return vida_atual

func is_morto() -> bool:
	return esta_morto
