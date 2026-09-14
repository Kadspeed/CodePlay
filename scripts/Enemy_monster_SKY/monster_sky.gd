extends CharacterBody2D
class_name MonsterSky

## =============================================================
## MONSTER_SKY - Inimigo voador com máquina de estados
## Estados: IDLE -> CHASE -> ATTACK -> HIT -> DEATH -> FALLING -> FADING
## Compatível com Godot 4.6 | Sem NavigationAgent | Sem AnimationPlayer
##
## Enquanto vivo, o inimigo VOA livremente (X e Y) em direção ao player,
## sem sofrer gravidade. Gravidade só é ativada após a animação de morte
## terminar, fazendo o corpo cair fisicamente até o chão.
## =============================================================


# -------------------------------------------------------------
# ENUM DE ESTADOS
# -------------------------------------------------------------
enum Estado { IDLE, CHASE, ATTACK, HIT, DEATH, FALLING, FADING }


# -------------------------------------------------------------
# VARIÁVEIS EXPORTADAS (organizadas por categoria)
# -------------------------------------------------------------

@export_group("Movimento")
@export var velocidade_voo: float = 80.0     # Velocidade ao perseguir o player (voo livre em X/Y)
@export var gravidade: float = 900.0         # Só é aplicada após a morte (estado FALLING)

@export_group("Vida")
@export var vida_maxima: int = 20

@export_group("Ataque")
@export var dano: int = 8
@export var cooldown_ataque: float = 2.0
@export var alcance_ataque: float = 50.0     # Autoconfigura a forma da AttackArea

@export_group("Detecção")
@export var tamanho_deteccao: float = 250.0  # Autoconfigura a forma da DetectionArea

@export_group("Hit e Invulnerabilidade")
@export var tempo_invulnerabilidade: float = 0.6
@export var forca_recuo: float = 60.0        # Pequeno empurrão ao levar dano (efeito visual)

@export_group("Morte")
@export var tempo_espera_antes_fade: float = 1.5  # Tempo parado no chão antes de começar o fade
@export var tempo_fade: float = 1.0


# -------------------------------------------------------------
# VARIÁVEIS INTERNAS
# -------------------------------------------------------------

var estado_atual: Estado = Estado.IDLE

var vida_atual: int = 0
var esta_morto: bool = false
var invulneravel: bool = false
var invulneravel_tempo_restante: float = 0.0

var player: Node2D = null
var esta_jogador_detectado: bool = false
var esta_no_alcance_attack: bool = false

var direcao: int = 1           # 1 = direita | -1 = esquerda
var pode_atacar: bool = true

# Controle interno da sequência de morte (sem usar await)
var pousou_no_chao: bool = false
var espera_fade_tempo_restante: float = 0.0
var fade_iniciado: bool = false


# -------------------------------------------------------------
# REFERÊNCIAS DE NÓS
# -------------------------------------------------------------

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D
@onready var area_deteccao: Area2D = $DetectionArea
@onready var area_attack: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer


# -------------------------------------------------------------
# CICLO DE VIDA
# -------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	vida_atual = vida_maxima
	estado_atual = Estado.IDLE

	attack_timer.wait_time = cooldown_ataque
	attack_timer.one_shot = true

	# Conecta todos os sinais necessários
	area_deteccao.body_entered.connect(_on_area_deteccao_body_entered)
	area_deteccao.body_exited.connect(_on_area_deteccao_body_exited)
	area_attack.body_entered.connect(_on_area_attack_body_entered)
	area_attack.body_exited.connect(_on_area_attack_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)

	_configurar_forma_area(area_deteccao, tamanho_deteccao)
	_configurar_forma_area(area_attack, alcance_ataque)

	# Garante que Attack, Take_hit e Death não fiquem em loop.
	_configurar_animacoes_nao_looping()

	_tocar_animacao("Idle")


func _physics_process(delta: float) -> void:
	_atualizar_invulnerabilidade(delta)

	match estado_atual:
		Estado.IDLE:
			_processar_idle(delta)
		Estado.CHASE:
			_processar_chase(delta)
		Estado.ATTACK:
			_processar_attack(delta)
		Estado.HIT:
			_processar_hit(delta)
		Estado.DEATH:
			_processar_death(delta)
		Estado.FALLING:
			_processar_falling(delta)
		Estado.FADING:
			_processar_fading(delta)

	move_and_slide()


func _atualizar_invulnerabilidade(delta: float) -> void:
	if invulneravel:
		invulneravel_tempo_restante -= delta
		if invulneravel_tempo_restante <= 0.0:
			invulneravel = false


# -------------------------------------------------------------
# ESTADO: IDLE
# -------------------------------------------------------------

func _processar_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	_tocar_animacao("Idle")


# -------------------------------------------------------------
# ESTADO: CHASE (voo livre em X e Y até o player)
# -------------------------------------------------------------

func _processar_chase(_delta: float) -> void:
	if not is_instance_valid(player):
		_mudar_estado(Estado.IDLE)
		return

	var direcao_ate_player: Vector2 = player.global_position - global_position

	if direcao_ate_player.length() > 1.0:
		velocity = direcao_ate_player.normalized() * velocidade_voo
	else:
		velocity = Vector2.ZERO

	if abs(direcao_ate_player.x) > 1.0:
		_virar_para(1 if direcao_ate_player.x > 0.0 else -1)

	_tocar_animacao("Idle") # Sem animação de voo própria: usa Idle como "voando"


# -------------------------------------------------------------
# ESTADO: ATTACK (para no ar e ataca)
# -------------------------------------------------------------

func _processar_attack(_delta: float) -> void:
	velocity = Vector2.ZERO

	if is_instance_valid(player):
		var diff_x: float = player.global_position.x - global_position.x
		if abs(diff_x) > 1.0:
			_virar_para(1 if diff_x > 0.0 else -1)


func _executar_ataque() -> void:
	pode_atacar = false
	_tocar_animacao("Attack")
	_aplicar_dano_area_attack()
	attack_timer.start()


func _aplicar_dano_area_attack() -> void:
	# Dano aplicado uma única vez por ataque: esta função só roda a
	# partir de _executar_ataque(), chamada apenas quando pode_atacar
	# é true — e essa flag é derrubada imediatamente em seguida.
	for corpo in area_attack.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("tomar_dano"):
			corpo.tomar_dano(dano)


# -------------------------------------------------------------
# ESTADO: HIT
# -------------------------------------------------------------

func _processar_hit(delta: float) -> void:
	# Desacelera o pequeno recuo suavemente até parar
	velocity = velocity.move_toward(Vector2.ZERO, forca_recuo * 3.0 * delta)


func _receber_hit(quem_atacou: Node2D) -> void:
	_mudar_estado(Estado.HIT)
	_tocar_animacao("Take_hit")

	var direcao_recuo: Vector2 = Vector2(-direcao, 0.0)
	if is_instance_valid(quem_atacou):
		var diff: Vector2 = global_position - quem_atacou.global_position
		if diff.length() > 0.1:
			direcao_recuo = diff.normalized()

	velocity = direcao_recuo * forca_recuo

	invulneravel = true
	invulneravel_tempo_restante = tempo_invulnerabilidade


# -------------------------------------------------------------
# ESTADO: DEATH (toca a animação uma vez, sem gravidade ainda)
# -------------------------------------------------------------

func _morrer() -> void:
	if esta_morto:
		return

	esta_morto = true
	velocity = Vector2.ZERO

	# Desativa detecção e ataque imediatamente, antes mesmo da
	# animação de morte terminar, para evitar dano/ataques póstumos.
	area_deteccao.set_deferred("monitoring", false)
	area_deteccao.set_deferred("monitorable", false)
	area_attack.set_deferred("monitoring", false)
	area_attack.set_deferred("monitorable", false)

	_mudar_estado(Estado.DEATH)
	_tocar_animacao("Death")


func _processar_death(_delta: float) -> void:
	# Fica parado no ar tocando a animação de morte. A transição para
	# FALLING acontece via sinal animation_finished (ver mais abaixo),
	# não aqui — assim garantimos que a animação toca por completo
	# antes da gravidade ser ativada.
	velocity = Vector2.ZERO


# -------------------------------------------------------------
# ESTADO: FALLING (gravidade ativa, cai até o chão)
# -------------------------------------------------------------

func _processar_falling(delta: float) -> void:
	if not pousou_no_chao:
		if is_on_floor():
			pousou_no_chao = true
			velocity = Vector2.ZERO
			espera_fade_tempo_restante = tempo_espera_antes_fade
		else:
			velocity.y += gravidade * delta
			velocity.x = 0.0
	else:
		# Já no chão: mantém o último frame da animação Death parado
		# e aguarda o tempo configurado antes de iniciar o fade.
		velocity = Vector2.ZERO
		espera_fade_tempo_restante -= delta
		if espera_fade_tempo_restante <= 0.0:
			_mudar_estado(Estado.FADING)


# -------------------------------------------------------------
# ESTADO: FADING (diminui a transparência e remove o nó)
# -------------------------------------------------------------

func _processar_fading(_delta: float) -> void:
	velocity = Vector2.ZERO

	if fade_iniciado:
		return
	fade_iniciado = true

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, tempo_fade)
	tween.tween_callback(queue_free)


# -------------------------------------------------------------
# TRANSIÇÃO DE ESTADOS
# -------------------------------------------------------------

func _mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return
	if esta_morto and novo_estado not in [Estado.DEATH, Estado.FALLING, Estado.FADING]:
		return

	estado_atual = novo_estado

	match novo_estado:
		Estado.IDLE:
			velocity = Vector2.ZERO
			_tocar_animacao("Idle")
		Estado.CHASE:
			pass # animação/movimento tratados em _processar_chase()
		Estado.ATTACK:
			velocity = Vector2.ZERO
			if pode_atacar:
				_executar_ataque()
			else:
				_tocar_animacao("Idle")
		Estado.HIT:
			pass # tratado em _receber_hit()
		Estado.DEATH:
			pass # tratado em _morrer()
		Estado.FALLING:
			pousou_no_chao = false
		Estado.FADING:
			fade_iniciado = false


# -------------------------------------------------------------
# FUNÇÕES AUXILIARES
# -------------------------------------------------------------

func _virar_para(nova_direcao: int) -> void:
	if nova_direcao == 0 or nova_direcao == direcao:
		return
	direcao = nova_direcao
	sprite.flip_h = direcao < 0


func _tocar_animacao(nome_animacao: String) -> void:
	if sprite.animation != nome_animacao:
		sprite.play(nome_animacao)


func _configurar_animacoes_nao_looping() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	for nome_animacao in ["Attack", "Take_hit", "Death"]:
		if frames.has_animation(nome_animacao):
			frames.set_animation_loop(nome_animacao, false)


func _configurar_forma_area(area: Area2D, tamanho: float) -> void:
	if area == null or tamanho <= 0.0:
		return
	for filho in area.get_children():
		if filho is CollisionShape2D and filho.shape != null:
			var forma: Shape2D = filho.shape
			if forma is CircleShape2D:
				forma.radius = tamanho
			elif forma is RectangleShape2D:
				forma.size = Vector2(tamanho * 2.0, forma.size.y)


# -------------------------------------------------------------
# SINAIS: DetectionArea
# -------------------------------------------------------------

func _on_area_deteccao_body_entered(body: Node2D) -> void:
	if esta_morto or not body.is_in_group("player"):
		return

	player = body
	esta_jogador_detectado = true
	print("Monster_sky detectou o Player")

	if estado_atual != Estado.HIT:
		_mudar_estado(Estado.CHASE)


func _on_area_deteccao_body_exited(body: Node2D) -> void:
	if body != player:
		return

	esta_jogador_detectado = false

	if not esta_no_alcance_attack:
		player = null
		if estado_atual == Estado.CHASE:
			_mudar_estado(Estado.IDLE)


# -------------------------------------------------------------
# SINAIS: AttackArea
# -------------------------------------------------------------

func _on_area_attack_body_entered(body: Node2D) -> void:
	if esta_morto or not body.is_in_group("player"):
		return

	player = body
	esta_no_alcance_attack = true

	if estado_atual != Estado.HIT:
		_mudar_estado(Estado.ATTACK)


func _on_area_attack_body_exited(body: Node2D) -> void:
	if body != player:
		return

	esta_no_alcance_attack = false

	if estado_atual == Estado.ATTACK:
		_mudar_estado(Estado.CHASE if esta_jogador_detectado else Estado.IDLE)


# -------------------------------------------------------------
# SINAL: AnimatedSprite2D.animation_finished
# -------------------------------------------------------------

func _on_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			if estado_atual == Estado.ATTACK:
				_tocar_animacao("Idle") # aguarda o cooldown "parado" visualmente
		"Take_hit":
			if not esta_morto:
				_mudar_estado(Estado.CHASE if esta_jogador_detectado else Estado.IDLE)
		"Death":
			# Animação de morte terminou: mantém o último frame (o
			# AnimatedSprite2D já para sozinho por não estar em loop)
			# e agora sim ativa a gravidade, indo para FALLING.
			if estado_atual == Estado.DEATH:
				_mudar_estado(Estado.FALLING)


# -------------------------------------------------------------
# SINAL: AttackCooldownTimer.timeout
# -------------------------------------------------------------

func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true

	if estado_atual == Estado.ATTACK and esta_no_alcance_attack:
		_executar_ataque()


# -------------------------------------------------------------
# API PÚBLICA (usada pelo Player)
# -------------------------------------------------------------

func tomar_dano(quantidade: int) -> void:
	if esta_morto or invulneravel:
		return

	quantidade = max(quantidade, 0)
	vida_atual = max(vida_atual - quantidade, 0)

	if vida_atual <= 0:
		_morrer()
	else:
		_receber_hit(player)


func get_dano() -> int:
	return dano


func get_vida() -> int:
	return vida_atual


func is_morto() -> bool:
	return esta_morto
