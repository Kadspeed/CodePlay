extends CharacterBody2D
class_name Cogumelo

## =============================================================
## COGUMELO - Inimigo com máquina de estados
## Estados: IDLE -> CHASE -> ATTACK -> HIT -> DEAD
## Compatível com Godot 4.6 | Sem NavigationAgent | Sem AnimationPlayer
## =============================================================
##
## SONS: seguindo o mesmo molde usado no Esqueleto. O Cogumelo tem 4
## AudioStreamPlayer2D na cena: Attack, Run, Take_hit e Death.
## - Attack e Take_hit e Death tocam direto no momento da ação
##   (mesmo padrão do Esqueleto: sem AnimationPlayer, então quem
##   dispara o som é o próprio código de estado).
## - Run usa um Timer criado em código (igual ao "Timer_Passo" do
##   Esqueleto) que toca o som em intervalo fixo enquanto o Cogumelo
##   está perseguindo o Player (estado CHASE).


# -------------------------------------------------------------
# ENUM DE ESTADOS
# -------------------------------------------------------------
enum Estado { IDLE, CHASE, ATTACK, HIT, DEAD }


# -------------------------------------------------------------
# VARIÁVEIS EXPORTADAS (organizadas por categoria)
# -------------------------------------------------------------

@export_group("Movimento")
@export var velocidade: float = 90.0        # Velocidade horizontal ao perseguir
@export var gravidade: float = 900.0        # Força da gravidade aplicada por segundo

@export_group("Vida")
@export var vida_maxima: int = 50

@export_group("Ataque")
@export var dano: int = 25                        # Dano causado ao player (1 vida = 25 HP, igual à queda)
@export var cooldown_ataque: float = 1.5          # Intervalo entre ataques
@export var alcance_ataque: float = 40.0          # Usado para autoconfigurar a Area_Attack (raio/tamanho)
@export var velocidade_animacao_ataque: float = 1.5  # Multiplicador de velocidade só da animação Attack (1.0 = normal, 2.0 = 2x mais rápida)

@export_group("Detecção")
@export var tamanho_deteccao: float = 220.0 # Usado para autoconfigurar a Area_Detecçao (raio/tamanho)

@export_group("Hit e Knockback")
@export var forca_knockback: float = 180.0
@export var forca_knockback_vertical: float = 120.0
@export var tempo_invulnerabilidade: float = 0.6
@export var tempo_fade_morte: float = 0.8

@export_group("Áudio - Passos")
@export var passo_intervalo: float = 0.4      # intervalo entre sons de "Run" ao perseguir

@export_group("Áudio - Volume")
@export var volume_extra_db: float = 0.0  # some esse valor ao volume atual de TODOS os sons do Cogumelo


# -------------------------------------------------------------
# VARIÁVEIS INTERNAS
# -------------------------------------------------------------

var estado_atual: Estado = Estado.IDLE

var vida_atual: int = 0
var esta_morto: bool = false
var invulneravel: bool = false

var player: Node2D = null
var esta_jogador_detectado: bool = false
var esta_no_alcance_attack: bool = false

var direcao: int = 1          # 1 = direita | -1 = esquerda
var pode_atacar: bool = true


# -------------------------------------------------------------
# REFERÊNCIAS DE NÓS
# -------------------------------------------------------------

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccao: Area2D = $Area_Detecçao
@onready var area_attack: Area2D = $Area_Attack
@onready var colisao: CollisionShape2D = $Colisao
@onready var floor_ray: RayCast2D = $FloorRayCast
@onready var marker: Marker2D = $Marker2D
@onready var attack_timer: Timer = $AttackCooldownTimer

@onready var som_attack: AudioStreamPlayer2D = $Attack
@onready var som_run: AudioStreamPlayer2D = $Run
@onready var som_take_hit: AudioStreamPlayer2D = $Take_hit
@onready var som_death: AudioStreamPlayer2D = $Death

## Timer criado por código (não precisa existir na cena) para tocar o
## som de "Run" em intervalo fixo enquanto persegue o Player, no
## mesmo molde do "timer_passo" do Esqueleto.
var timer_passo: Timer


# -------------------------------------------------------------
# CICLO DE VIDA
# -------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	vida_atual = vida_maxima
	estado_atual = Estado.IDLE

	# Configura o timer de cooldown de ataque
	attack_timer.wait_time = cooldown_ataque
	attack_timer.one_shot = true

	# Timer de passo (som "Run"), criado em código para não precisar
	# adicionar nenhum nó novo na cena.
	timer_passo = Timer.new()
	timer_passo.one_shot = false
	timer_passo.wait_time = passo_intervalo
	add_child(timer_passo)
	timer_passo.timeout.connect(_on_timer_passo_timeout)

	# Conecta todos os sinais necessários
	area_deteccao.body_entered.connect(_on_area_deteccao_body_entered)
	area_deteccao.body_exited.connect(_on_area_deteccao_body_exited)
	area_attack.body_entered.connect(_on_area_attack_body_entered)
	area_attack.body_exited.connect(_on_area_attack_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)

	# Ajusta automaticamente o tamanho das áreas de detecção/ataque
	# conforme as variáveis exportadas (evita depender só do editor).
	_configurar_forma_area(area_deteccao, tamanho_deteccao)
	_configurar_forma_area(area_attack, alcance_ataque)

	# Garante que animações de ação não fiquem em loop (evita bugs
	# de state machine caso alguém esqueça de desmarcar no editor).
	_configurar_animacoes_nao_looping()

	# Aumenta o volume de todos os sons do Cogumelo de uma vez, sem
	# precisar clicar em cada AudioStreamPlayer2D no editor.
	_aplicar_volume_extra()

	if floor_ray:
		floor_ray.enabled = true

	_tocar_animacao("Idle")


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	_aplicar_gravidade(delta)

	match estado_atual:
		Estado.IDLE:
			_processar_idle(delta)
		Estado.CHASE:
			_processar_chase(delta)
		Estado.ATTACK:
			_processar_attack(delta)
		Estado.HIT:
			_processar_hit(delta)
		Estado.DEAD:
			pass

	move_and_slide()


# -------------------------------------------------------------
# ESTADO: IDLE
# -------------------------------------------------------------

func _processar_idle(_delta: float) -> void:
	velocity.x = 0.0
	_tocar_animacao("Idle")


# -------------------------------------------------------------
# ESTADO: CHASE
# -------------------------------------------------------------

func _processar_chase(_delta: float) -> void:
	if not is_instance_valid(player):
		_mudar_estado(Estado.IDLE)
		return

	var diferenca_x: float = player.global_position.x - global_position.x
	var nova_direcao: int = direcao
	if abs(diferenca_x) > 1.0:
		nova_direcao = 1 if diferenca_x > 0.0 else -1

	if nova_direcao != direcao:
		_virar_para(nova_direcao)

	# Evita cair em buracos: se não houver chão à frente, para de andar.
	if _detectar_borda():
		velocity.x = 0.0
	else:
		velocity.x = direcao * velocidade

	_tocar_animacao("Run")


func _detectar_borda() -> bool:
	if floor_ray == null:
		return false
	return not floor_ray.is_colliding()


# -------------------------------------------------------------
# ESTADO: ATTACK
# -------------------------------------------------------------

func _processar_attack(_delta: float) -> void:
	velocity.x = 0.0

	if is_instance_valid(player):
		var diferenca_x: float = player.global_position.x - global_position.x
		if abs(diferenca_x) > 1.0:
			_virar_para(1 if diferenca_x > 0.0 else -1)


func _executar_ataque() -> void:
	pode_atacar = false
	_tocar_animacao("Attack")
	_aplicar_dano_area_attack()
	som_attack.play()
	attack_timer.start()


func _aplicar_dano_area_attack() -> void:
	# Causa dano apenas uma vez por ataque: esta função só é chamada
	# a partir de _executar_ataque(), que por sua vez só roda quando
	# pode_atacar é true (e é imediatamente travada logo em seguida).
	for corpo in area_attack.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("tomar_dano"):
			print("🍄 Cogumelo (", name, ") atacou o player! Dano: ", dano)
			corpo.tomar_dano(dano)


# -------------------------------------------------------------
# ESTADO: HIT
# -------------------------------------------------------------

func _processar_hit(delta: float) -> void:
	# Desacelera o knockback suavemente até parar
	velocity.x = move_toward(velocity.x, 0.0, forca_knockback * 2.0 * delta)


func _receber_hit(quem_atacou: Node2D) -> void:
	_mudar_estado(Estado.HIT)
	_tocar_animacao("Take_Hit")
	som_take_hit.play()

	# Knockback afastando o inimigo do player (ou da direção oposta
	# ao que ele estava olhando, caso não haja referência válida).
	var direcao_knockback: int = -direcao
	if is_instance_valid(quem_atacou):
		var diff: float = global_position.x - quem_atacou.global_position.x
		if abs(diff) > 0.1:
			direcao_knockback = 1 if diff > 0.0 else -1

	velocity.x = direcao_knockback * forca_knockback
	velocity.y = -forca_knockback_vertical

	_iniciar_invulnerabilidade()


func _iniciar_invulnerabilidade() -> void:
	invulneravel = true
	await get_tree().create_timer(tempo_invulnerabilidade).timeout
	invulneravel = false


# -------------------------------------------------------------
# ESTADO: DEAD
# -------------------------------------------------------------

func _morrer() -> void:
	if esta_morto:
		return

	esta_morto = true
	estado_atual = Estado.DEAD
	velocity = Vector2.ZERO

	timer_passo.stop()

	_tocar_animacao("Death")
	som_death.play()

	# Desativa colisões e áreas (set_deferred evita erros de
	# "modificação durante callback de física").
	colisao.set_deferred("disabled", true)
	area_deteccao.set_deferred("monitoring", false)
	area_deteccao.set_deferred("monitorable", false)
	area_attack.set_deferred("monitoring", false)
	area_attack.set_deferred("monitorable", false)


func _fade_out_e_remover() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, tempo_fade_morte)
	tween.tween_callback(queue_free)


# -------------------------------------------------------------
# TRANSIÇÃO DE ESTADOS
# -------------------------------------------------------------

func _mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado or esta_morto:
		return

	# Para o som de passo sempre que sair do estado CHASE (evita o som
	# de "Run" continuar tocando depois que o Cogumelo já parou).
	if estado_atual == Estado.CHASE and novo_estado != Estado.CHASE:
		timer_passo.stop()

	estado_atual = novo_estado

	match novo_estado:
		Estado.IDLE:
			velocity.x = 0.0
			_tocar_animacao("Idle")
		Estado.CHASE:
			_tocar_animacao("Run")
			timer_passo.start()
		Estado.ATTACK:
			velocity.x = 0.0
			if pode_atacar:
				_executar_ataque()
			else:
				_tocar_animacao("Idle")
		Estado.HIT:
			pass # animação e knockback já tratados em _receber_hit()
		Estado.DEAD:
			pass # tratado em _morrer()


# -------------------------------------------------------------
# FUNÇÕES AUXILIARES
# -------------------------------------------------------------

func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _virar_para(nova_direcao: int) -> void:
	if nova_direcao == 0 or nova_direcao == direcao:
		return

	direcao = nova_direcao
	sprite.flip_h = direcao < 0

	# Espelha a posição do raycast de chão e do marker para que
	# continuem apontando/ficando "na frente" do inimigo.
	if floor_ray:
		var pos_ray: Vector2 = floor_ray.position
		pos_ray.x = abs(pos_ray.x) * direcao
		floor_ray.position = pos_ray

	if marker:
		var pos_marker: Vector2 = marker.position
		pos_marker.x = abs(pos_marker.x) * direcao
		marker.position = pos_marker


func _tocar_animacao(nome_animacao: String) -> void:
	# A animação de ataque usa um multiplicador de velocidade próprio
	# (velocidade_animacao_ataque) para não depender só do FPS
	# configurado no SpriteFrames. As demais tocam na velocidade normal.
	sprite.speed_scale = velocidade_animacao_ataque if nome_animacao == "Attack" else 1.0

	# CORREÇÃO: além de checar se o nome da animação mudou, checa se
	# ela já está tocando de fato. Sem isso, se o AnimatedSprite2D já
	# vier com "Idle" selecionada por padrão no editor (mas parada),
	# o play() nunca era chamado no _ready() e a animação Idle ficava
	# travada no primeiro frame.
	if sprite.animation != nome_animacao or not sprite.is_playing():
		sprite.play(nome_animacao)


func _configurar_animacoes_nao_looping() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return

	for nome_animacao in ["Attack", "Take_Hit", "Death"]:
		if frames.has_animation(nome_animacao):
			frames.set_animation_loop(nome_animacao, false)


func _configurar_forma_area(area: Area2D, tamanho: float) -> void:
	# Ajusta o CollisionShape2D filho da área conforme a variável
	# exportada, suportando os formatos mais comuns.
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
# SOM DE PASSO / "RUN" (mesmo molde do Esqueleto)
# -------------------------------------------------------------

func _on_timer_passo_timeout() -> void:
	if estado_atual == Estado.CHASE:
		som_run.play()


# -------------------------------------------------------------
# VOLUME DOS SONS (mesmo molde do Esqueleto)
# -------------------------------------------------------------
## Soma "volume_extra_db" ao volume atual de cada AudioStreamPlayer2D,
## em vez de sobrescrever — então se você já tiver ajustado algum no
## Inspector, esse ajuste continua valendo, só fica mais alto.

func _aplicar_volume_extra() -> void:
	for som in [som_attack, som_run, som_take_hit, som_death]:
		som.volume_db += volume_extra_db


# -------------------------------------------------------------
# SINAIS: Area_Detecçao
# -------------------------------------------------------------

func _on_area_deteccao_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player = body
	esta_jogador_detectado = true
	print("Cogumelo detectou o Player")

	if estado_atual != Estado.HIT and estado_atual != Estado.DEAD:
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
# SINAIS: Area_Attack
# -------------------------------------------------------------

func _on_area_attack_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player = body
	esta_no_alcance_attack = true

	if estado_atual != Estado.HIT and estado_atual != Estado.DEAD:
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
				# Aguarda o cooldown "descansando" visualmente em Idle.
				# O próximo ataque é disparado por _on_attack_cooldown_timeout().
				_tocar_animacao("Idle")
		"Take_Hit":
			if not esta_morto:
				_mudar_estado(Estado.CHASE if esta_jogador_detectado else Estado.IDLE)
		"Death":
			_fade_out_e_remover()


# -------------------------------------------------------------
# SINAL: AttackCooldownTimer.timeout
# -------------------------------------------------------------

func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true

	# Se o player ainda estiver no alcance e o cogumelo ainda em ATTACK,
	# encadeia o próximo golpe automaticamente.
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
