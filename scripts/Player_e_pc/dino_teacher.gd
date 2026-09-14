# =============================================================================
# DINO TEACHER - NPC EDUCATIVO (VERSÃO FINAL)
# =============================================================================
# Engine: Godot 4.6
# Descrição: Professor dinossauro amigável que acompanha o jogador,
#           fornece feedback educativo e se comporta como um parceiro.
# =============================================================================

extends CharacterBody2D
class_name DinoTeacher

# =============================================================================
# SINAIS
# =============================================================================

signal feedback_mostrado(texto: String, tipo: String)
signal feedback_escondido()
signal player_perdido()
signal pulou_obstaculo()

# =============================================================================
# CONSTANTES
# =============================================================================

# Movimento
const SPEED: float = 250.0          # Velocidade de perseguição (mais lento que inimigo)
const GRAVIDADE: float = 980.0
const FORCA_PULO: float = -900.0    # Pulo mais suave
const DISTANCIA_DESEJADA: float = 80.0   # Distância que mantém do player
const DISTANCIA_MAXIMA: float = 350.0    # Distância máxima antes de teleportar

# Detecção de obstáculos
const ALTURA_MIN_PULO: float = 30.0
const DISTANCIA_DETECCAO: float = 50.0
const DISTANCIA_DEPRESSAO: float = 60.0
const ALTURA_RAYCAST: float = 35.0

# Feedback
const TEMPO_FEEDBACK: float = 4.0
const VELOCIDADE_DATILOGRAFIA: float = 0.04
const TAMANHO_MAX_TEXTO: int = 140

# =============================================================================
# EXPORTED VARIABLES
# =============================================================================

@export_group("Movimento")
@export var velocidade: float = SPEED
@export var forca_pulo: float = FORCA_PULO
@export var gravidade: float = GRAVIDADE

@export_group("Comportamento")
@export var distancia_desejada: float = DISTANCIA_DESEJADA
@export var distancia_max_teleporte: float = DISTANCIA_MAXIMA
@export var suavizacao_movimento: float = 0.12

@export_group("Feedback")
@export var tempo_exibicao: float = TEMPO_FEEDBACK
@export var velocidade_digitacao: float = VELOCIDADE_DATILOGRAFIA

@export_group("Animações")
@export var anim_idle: String = "idle"
@export var anim_run: String = "run"
@export var anim_jump: String = "jump"

# =============================================================================
# ENUM - MÁQUINA DE ESTADOS
# =============================================================================

enum Estado {
	IDLE,       # Parado, esperando o player
	FOLLOW,     # Seguindo o player
	JUMP,       # Pulando obstáculo
	TALKING     # Falando (feedback visível)
}

# =============================================================================
# VARIÁVEIS INTERNAS
# =============================================================================

# Máquina de estados
var estado_atual: Estado = Estado.IDLE
var estado_anterior: Estado = Estado.IDLE

# Referências
var player: CharacterBody2D = null
var posicao_alvo: Vector2 = Vector2.ZERO
var direcao_atual: int = 1
var esta_pulando: bool = false
var pode_pular: bool = true

# Movimento suave
var velocidade_suavizada: float = 0.0

# Feedback
var feedback_visivel: bool = false
var texto_completo: String = ""
var texto_atual: String = ""
var digitacao_index: int = 0
var digitacao_timer: float = 0.0
var cor_feedback: Color = Color.WHITE
var tipo_feedback: String = "informacao"

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var balao_fala: Control = $BalaoFala
@onready var label_fala: Label = $BalaoFala/Label

# Nodes criados dinamicamente
var raycast_parede: RayCast2D
var raycast_chao_frente: RayCast2D
var raycast_depressao: RayCast2D
var timer_feedback: Timer
var timer_busca_player: Timer
var timer_pulo: Timer
var tween_balão: Tween

# =============================================================================
# LISTAS DE MENSAGENS
# =============================================================================

const ELOGIOS: Array[String] = [
	"🎉 Excelente!",
	"🌟 Muito bem!",
	"💪 Parabéns!",
	"🎯 Perfeito!",
	"🏆 Sensacional!",
	"📚 Bom trabalho!",
	"✨ Incrível!",
	"🌈 Fantástico!",
	"⭐ Nota 10!",
	"🎈 Continue assim!"
]

const DICAS: Array[String] = [
	"💡 Tente pensar mais um pouco...",
	"💡 Você está quase lá!",
	"💡 Releia a pergunta com calma.",
	"💡 Já tentou ver por outro ângulo?",
	"💡 Confie no seu raciocínio!",
	"💡 Uma pequena dica: preste atenção nos detalhes."
]

const MENSAGENS_DISQUETE: Array[String] = [
	"📀 Você encontrou um novo conhecimento!",
	"📀 Disquete coletado! Vamos aprender!",
	"📀 Mais um pedaço da história!",
	"📀 Conhecimento é poder!"
]

const MENSAGENS_PUZZLE: Array[String] = [
	"🧩 Vamos resolver esse quebra-cabeça!",
	"🧩 Pense com calma, você consegue!",
	"🧩 Cada peça tem seu lugar!",
	"🧩 Quebra-cabeça interessante!"
]

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================

func _ready() -> void:
	"""Configuração inicial do DinoTeacher."""
	# Configurar grupos
	add_to_group("dino_teacher")
	
	# Configurar física
	_configurar_fisica()
	
	# Configurar UI do balão
	_configurar_balao()
	
	# Criar nós auxiliares
	_criar_raycasts()
	_criar_timers()
	
	# Iniciar busca pelo player
	call_deferred("encontrar_player")
	
	# Estado inicial
	_mudar_estado(Estado.IDLE)
	
	print("🦕 DinoTeacher inicializado com sucesso!")

func _configurar_fisica() -> void:
	"""
	Configura camadas de colisão para o CharacterBody2D.
	
	RECOMENDAÇÃO DE LAYERS:
	- Layer 1: Player
	- Layer 2: DinoTeacher (NPCs amigáveis)
	- Layer 3: Chão/Plataformas
	- Layer 4: Obstáculos (paredes, objetos)
	
	O DinoTeacher está na Layer 2 e colide com:
	- Player (Layer 1) para não atravessá-lo
	- Chão (Layer 3) para ficar no chão
	"""
	# O DinoTeacher pertence à Layer 2
	set_collision_layer_value(2, true)
	
	# Colide com Player (1) e Chão (3)
	set_collision_mask_value(1, true)  # Player
	set_collision_mask_value(3, true)  # Chão
	
	# Não colide com outros da mesma camada
	set_collision_mask_value(2, false)

func _configurar_balao() -> void:
	"""Configura o visual e comportamento do balão de fala."""
	if balao_fala:
		balao_fala.visible = false
		balao_fala.position = Vector2(0, -70)
		balao_fala.size = Vector2(280, 100)
		balao_fala.add_theme_stylebox_override("panel", _criar_estilo_padrao())
		# Definir escala inicial para animação
		balao_fala.scale = Vector2(0.8, 0.8)
		balao_fala.modulate = Color.TRANSPARENT
	
	if label_fala:
		label_fala.add_theme_font_size_override("font_size", 15)
		label_fala.add_theme_color_override("font_color", Color.WHITE)
		label_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_fala.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_fala.size = Vector2(260, 80)
		label_fala.position = Vector2(10, 10)

func _criar_estilo_padrao() -> StyleBoxFlat:
	"""Cria o estilo visual base do balão."""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.shadow_color = Color(0, 0, 0, 0.4)
	return style

# =============================================================================
# CRIAÇÃO DE NÓS AUXILIARES
# =============================================================================

func _criar_raycasts() -> void:
	"""Cria os RayCasts para detecção de obstáculos."""
	# RayCast para parede à frente
	raycast_parede = RayCast2D.new()
	raycast_parede.name = "RayCastParede"
	raycast_parede.target_position = Vector2(DISTANCIA_DETECCAO, 0)
	raycast_parede.collision_mask = 3 | 4  # Chão e obstáculos
	raycast_parede.enabled = true
	raycast_parede.hit_from_inside = true
	add_child(raycast_parede)
	
	# RayCast para chão à frente (detecta buracos)
	raycast_chao_frente = RayCast2D.new()
	raycast_chao_frente.name = "RayCastChaoFrente"
	raycast_chao_frente.target_position = Vector2(DISTANCIA_DEPRESSAO, ALTURA_RAYCAST)
	raycast_chao_frente.collision_mask = 3  # Apenas chão
	raycast_chao_frente.enabled = true
	raycast_chao_frente.hit_from_inside = true
	add_child(raycast_chao_frente)
	
	# RayCast para depressão (buraco mais fundo)
	raycast_depressao = RayCast2D.new()
	raycast_depressao.name = "RayCastDepressao"
	raycast_depressao.target_position = Vector2(DISTANCIA_DEPRESSAO, ALTURA_RAYCAST + 20)
	raycast_depressao.collision_mask = 3
	raycast_depressao.enabled = true
	raycast_depressao.hit_from_inside = true
	add_child(raycast_depressao)
	
	# Atualizar direção inicial
	_atualizar_raycasts_direcao(direcao_atual)

func _criar_timers() -> void:
	"""Cria os timers para feedback, busca e controle de pulo."""
	# Timer para feedback
	timer_feedback = Timer.new()
	timer_feedback.name = "TimerFeedback"
	timer_feedback.wait_time = tempo_exibicao
	timer_feedback.one_shot = true
	timer_feedback.timeout.connect(_on_timer_feedback_timeout)
	add_child(timer_feedback)
	
	# Timer para busca periódica do player
	timer_busca_player = Timer.new()
	timer_busca_player.name = "TimerBuscaPlayer"
	timer_busca_player.wait_time = 0.5
	timer_busca_player.one_shot = false
	timer_busca_player.timeout.connect(_on_timer_busca_player_timeout)
	add_child(timer_busca_player)
	timer_busca_player.start()
	
	# Timer para controle de pulo (evita pulos consecutivos)
	timer_pulo = Timer.new()
	timer_pulo.name = "TimerPulo"
	timer_pulo.wait_time = 0.2
	timer_pulo.one_shot = true
	timer_pulo.timeout.connect(_on_timer_pulo_timeout)
	add_child(timer_pulo)

# =============================================================================
# MÁQUINA DE ESTADOS
# =============================================================================

func _mudar_estado(novo_estado: Estado) -> void:
	"""Transição de estado com log."""
	if estado_atual == novo_estado:
		return
	
	estado_anterior = estado_atual
	estado_atual = novo_estado
	
	# Ações de entrada
	match novo_estado:
		Estado.IDLE:
			_on_enter_idle()
		Estado.FOLLOW:
			_on_enter_follow()
		Estado.JUMP:
			_on_enter_jump()
		Estado.TALKING:
			_on_enter_talking()
	
	# Debug (opcional)
	# print("🦕 Estado: ", Estado.keys()[estado_atual])

func _on_enter_idle() -> void:
	"""Entrando em IDLE."""
	if sprite and _animacao_existe(anim_idle):
		sprite.play(anim_idle)
	velocity.x = 0

func _on_enter_follow() -> void:
	"""Entrando em FOLLOW."""
	if sprite and _animacao_existe(anim_run):
		sprite.play(anim_run)

func _on_enter_jump() -> void:
	"""Entrando em JUMP."""
	if sprite and _animacao_existe(anim_jump):
		sprite.play(anim_jump)

func _on_enter_talking() -> void:
	"""Entrando em TALKING (feedback visível)."""
	# Não altera animação, apenas impede movimento durante fala se desejado
	pass

# =============================================================================
# PROCESSAMENTO PRINCIPAL
# =============================================================================

func _physics_process(delta: float) -> void:
	"""Loop principal de física."""
	# Buscar player se não tiver
	if not player:
		encontrar_player()
		return
	
	# Aplicar gravidade
	_aplicar_gravidade(delta)
	
	# Processar estado atual
	_processar_estado(delta)
	
	# Aplicar movimento
	move_and_slide()
	
	# Atualizar animação
	_atualizar_animacao()
	
	# Atualizar efeito de digitação
	_processar_digitacao(delta)

func _aplicar_gravidade(delta: float) -> void:
	"""Aplica gravidade e limita velocidade de queda."""
	if not is_on_floor():
		velocity.y += gravidade * delta
		velocity.y = min(velocity.y, 600.0)
	else:
		esta_pulando = false
		# Se estava pulando e agora está no chão, voltar para FOLLOW ou IDLE
		if estado_atual == Estado.JUMP:
			if player and _deve_seguir():
				_mudar_estado(Estado.FOLLOW)
			else:
				_mudar_estado(Estado.IDLE)

func _processar_estado(delta: float) -> void:
	"""Processa a lógica do estado atual."""
	match estado_atual:
		Estado.IDLE:
			_processar_idle(delta)
		Estado.FOLLOW:
			_processar_follow(delta)
		Estado.JUMP:
			_processar_jump(delta)
		Estado.TALKING:
			_processar_talking(delta)

# =============================================================================
# ESTADO IDLE
# =============================================================================

func _processar_idle(_delta: float) -> void:
	"""Fica parado até o player se aproximar ou ser detectado."""
	if player and _deve_seguir():
		_mudar_estado(Estado.FOLLOW)

func _deve_seguir() -> bool:
	"""Verifica se deve começar a seguir o player."""
	if not player:
		return false
	var dist = global_position.distance_to(player.global_position)
	return dist > distancia_desejada + 20

# =============================================================================
# ESTADO FOLLOW
# =============================================================================

func _processar_follow(delta: float) -> void:
	"""Segue o player mantendo distância, desviando de obstáculos."""
	if not player:
		_mudar_estado(Estado.IDLE)
		return
	
	# Calcular posição alvo (atrás do player)
	_calcular_posicao_alvo()
	
	var distancia = global_position.distance_to(posicao_alvo)
	
	# Se já está perto, parar
	if distancia < 10:
		velocity.x = move_toward(velocity.x, 0, velocidade * delta * 5)
		# Mudar para IDLE se estiver muito perto e não houver necessidade de seguir
		if distancia < 20:
			_mudar_estado(Estado.IDLE)
		return
	
	# Direção do movimento
	var dir = (posicao_alvo - global_position).normalized()
	var velocidade_x = dir.x * velocidade
	
	# Verificar se deve pular
	if _deve_pular(velocidade_x):
		_pular()
		return
	
	# Suavizar a velocidade
	velocity.x = lerp(velocity.x, velocidade_x, 1.0 - exp(-delta * 10))
	
	# Atualizar direção visual
	if abs(velocity.x) > 10:
		direcao_atual = sign(velocity.x)
		_atualizar_raycasts_direcao(direcao_atual)
		sprite.flip_h = direcao_atual < 0
	
	# Teleporte se estiver muito longe
	if distancia > distancia_max_teleporte:
		_teleportar_para_player()

func _calcular_posicao_alvo() -> void:
	"""Define a posição alvo baseada na posição e direção do player."""
	if not player:
		return
	
	# Direção que o player está olhando (se tiver o método)
	var player_direcao = 1
	if player.has_method("get_direcao"):
		player_direcao = player.get_direcao()
	
	# Ficar atrás do player (lado oposto)
	var lado = -player_direcao
	var target = player.global_position + Vector2(lado * distancia_desejada, 0)
	target.y = player.global_position.y
	
	# Suavizar o alvo
	posicao_alvo = posicao_alvo.lerp(target, suavizacao_movimento)

# =============================================================================
# ESTADO JUMP
# =============================================================================

func _processar_jump(_delta: float) -> void:
	"""Durante o pulo, apenas aguarda o fim da animação ou toque no chão."""
	# O retorno ao chão é tratado em _aplicar_gravidade
	pass

# =============================================================================
# ESTADO TALKING
# =============================================================================

func _processar_talking(_delta: float) -> void:
	"""Durante a fala, fica parado (opcional)."""
	# Pode parar o movimento ou permitir que continue seguindo
	# Aqui optamos por parar durante a fala para dar ênfase
	velocity.x = move_toward(velocity.x, 0, velocidade * _delta * 5)

# =============================================================================
# DETECÇÃO DE OBSTÁCULOS E PULO
# =============================================================================

func _deve_pular(velocidade_x: float) -> bool:
	"""
	Determina se deve pular com base em obstáculos e buracos.
	
	Args:
		velocidade_x: Velocidade horizontal atual
	
	Returns:
		bool: True se deve pular
	"""
	if velocidade_x == 0 or not is_on_floor() or esta_pulando or not pode_pular:
		return false
	
	var dir = sign(velocidade_x)
	_atualizar_raycasts_direcao(dir)
	
	# Verificar obstáculo à frente
	if raycast_parede and raycast_parede.is_colliding():
		var altura = _get_altura_obstaculo(raycast_parede.get_collider())
		if altura > ALTURA_MIN_PULO:
			return true
	
	# Verificar buraco à frente
	if _tem_buraco_na_frente():
		return true
	
	return false

func _tem_buraco_na_frente() -> bool:
	"""Verifica se há um buraco à frente usando os RayCasts."""
	if raycast_chao_frente and not raycast_chao_frente.is_colliding():
		if raycast_depressao and not raycast_depressao.is_colliding():
			return true
	return false

func _get_altura_obstaculo(obstaculo: Node) -> float:
	"""Tenta obter a altura de um obstáculo."""
	if obstaculo is CollisionShape2D:
		var shape = obstaculo.shape
		if shape is RectangleShape2D:
			return shape.size.y
		elif shape is CapsuleShape2D:
			return shape.height
	elif obstaculo is TileMap:
		return 100.0  # Valor padrão para tilemap
	return 50.0

func _pular() -> void:
	"""Executa o pulo."""
	if not is_on_floor() or esta_pulando or not pode_pular:
		return
	
	velocity.y = forca_pulo
	esta_pulando = true
	pode_pular = false
	_mudar_estado(Estado.JUMP)
	
	if timer_pulo:
		timer_pulo.start()
	
	pulou_obstaculo.emit()
	print("🦕 DinoTeacher pulou!")

func _on_timer_pulo_timeout() -> void:
	"""Libera o pulo novamente."""
	pode_pular = true

func _teleportar_para_player() -> void:
	"""Teleporta o NPC para perto do player se estiver muito longe."""
	if not player:
		return
	
	var dir = 1
	if player.has_method("get_direcao"):
		dir = -player.get_direcao()
	
	global_position = player.global_position + Vector2(dir * distancia_desejada, 0)
	velocity = Vector2.ZERO
	_mudar_estado(Estado.FOLLOW)
	print("🦕 DinoTeacher teleportado!")

# =============================================================================
# RAYCASTS - ATUALIZAÇÃO
# =============================================================================

func _atualizar_raycasts_direcao(dir: int) -> void:
	"""Atualiza a direção dos RayCasts e força atualização."""
	if raycast_parede:
		raycast_parede.target_position = Vector2(DISTANCIA_DETECCAO * dir, 0)
		raycast_parede.force_raycast_update()
	
	if raycast_chao_frente:
		raycast_chao_frente.target_position = Vector2(DISTANCIA_DEPRESSAO * dir, ALTURA_RAYCAST)
		raycast_chao_frente.force_raycast_update()
	
	if raycast_depressao:
		raycast_depressao.target_position = Vector2(DISTANCIA_DEPRESSAO * dir, ALTURA_RAYCAST + 20)
		raycast_depressao.force_raycast_update()

# =============================================================================
# ANIMAÇÕES
# =============================================================================

func _atualizar_animacao() -> void:
	"""Atualiza a animação baseada no estado e no chão."""
	if not sprite:
		return
	
	# Se estiver falando, não interromper a animação (opcional)
	if estado_atual == Estado.TALKING:
		return
	
	if not is_on_floor():
		if _animacao_existe(anim_jump):
			sprite.play(anim_jump)
	elif abs(velocity.x) > 20:
		if _animacao_existe(anim_run):
			sprite.play(anim_run)
	else:
		if _animacao_existe(anim_idle):
			sprite.play(anim_idle)

func _animacao_existe(nome: String) -> bool:
	"""Verifica se uma animação existe no sprite."""
	return sprite.sprite_frames and sprite.sprite_frames.has_animation(nome)

# =============================================================================
# ANIMAÇÕES DE EMOÇÃO (FELICIDADE / TRISTEZA)
# =============================================================================

func _pular_felicidade() -> void:
	"""Pulo curto de felicidade."""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y - 25, 0.15)
	tween.tween_property(self, "position:y", position.y, 0.15)

func _pular_tristeza() -> void:
	"""Leve inclinação para baixo (tristeza)."""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "position:y", position.y + 6, 0.1)
	tween.tween_property(self, "position:y", position.y, 0.1)

# =============================================================================
# SISTEMA DE FEEDBACK EDUCACIONAL (MELHORADO)
# =============================================================================

func dar_feedback(resultado: Dictionary) -> void:
	"""
	Processa o resultado de uma ação do jogador e exibe feedback apropriado.
	
	Args:
		resultado: Dicionário com chaves:
			- status (String): "correto", "erro", "aviso", "info"
			- topico (String): Título do erro
			- erros (Array): Lista de erros
			- dica (String): Dica para o jogador
	"""
	var mensagem: String = ""
	var tipo: String = ""
	var cor: Color = Color.WHITE
	
	match resultado.get("status", ""):
		"correto":
			mensagem = gerar_elogio()
			tipo = "sucesso"
			cor = Color.GREEN
			_pular_felicidade()
		"erro":
			mensagem = _gerar_explicacao_erros(resultado)
			tipo = "erro"
			cor = Color.RED
			_pular_tristeza()
		"aviso":
			mensagem = resultado.get("mensagem", "⚠️ Atenção!")
			tipo = "aviso"
			cor = Color.YELLOW
		_:
			mensagem = resultado.get("mensagem", "ℹ️ Informação")
			tipo = "informacao"
			cor = Color.CYAN
	
	mostrar_feedback(mensagem, cor, tipo)

func mostrar_feedback(texto: String, cor: Color = Color.WHITE, tipo: String = "informacao") -> void:
	"""
	Exibe o feedback com efeito de digitação e animação de entrada.
	
	Args:
		texto: Mensagem a ser exibida
		cor: Cor do texto
		tipo: Tipo de mensagem (sucesso, erro, aviso, informacao)
	"""
	if not balao_fala or not label_fala:
		return
	
	# Limitar tamanho do texto
	if texto.length() > TAMANHO_MAX_TEXTO:
		texto = texto.substr(0, TAMANHO_MAX_TEXTO - 3) + "..."
	
	# Configurar estilo do balão conforme o tipo
	var style = _criar_estilo_por_tipo(tipo, cor)
	balao_fala.add_theme_stylebox_override("panel", style)
	
	# Preparar dados para digitação
	texto_completo = texto
	texto_atual = ""
	digitacao_index = 0
	digitacao_timer = 0.0
	cor_feedback = cor
	tipo_feedback = tipo
	feedback_visivel = true
	
	# Mostrar balão com animação
	balao_fala.visible = true
	balao_fala.modulate = Color.TRANSPARENT
	balao_fala.scale = Vector2(0.8, 0.8)
	_animar_entrada_balão()
	
	# Iniciar timer para esconder
	if timer_feedback:
		timer_feedback.stop()
		timer_feedback.start()
	
	# Mudar estado para TALKING (para parar movimento durante fala, opcional)
	_mudar_estado(Estado.TALKING)
	
	feedback_mostrado.emit(texto, tipo)
	print("🦕 DinoTeacher: ", texto)

func _processar_digitacao(delta: float) -> void:
	"""Processa o efeito de digitação progressiva."""
	if not feedback_visivel or not texto_completo:
		return
	
	if digitacao_index < texto_completo.length():
		digitacao_timer += delta
		if digitacao_timer >= velocidade_digitacao:
			digitacao_timer = 0.0
			digitacao_index += 1
			texto_atual = texto_completo.substr(0, digitacao_index)
			label_fala.text = texto_atual

func _animar_entrada_balão() -> void:
	"""Anima a entrada do balão com escala e transparência."""
	if not balao_fala:
		return
	
	if tween_balão:
		tween_balão.kill()
	
	tween_balão = create_tween()
	tween_balão.set_ease(Tween.EASE_OUT)
	tween_balão.set_trans(Tween.TRANS_BACK)
	
	tween_balão.tween_property(balao_fala, "modulate:a", 1.0, 0.25)
	tween_balão.parallel().tween_property(balao_fala, "scale", Vector2.ONE, 0.25)

func _animar_saida_balão() -> void:
	"""Anima a saída do balão com fade e encolhimento."""
	if not balao_fala:
		return
	
	if tween_balão:
		tween_balão.kill()
	
	tween_balão = create_tween()
	tween_balão.set_ease(Tween.EASE_IN)
	tween_balão.set_trans(Tween.TRANS_QUINT)
	
	tween_balão.tween_property(balao_fala, "modulate:a", 0.0, 0.25)
	tween_balão.parallel().tween_property(balao_fala, "scale", Vector2(0.8, 0.8), 0.25)
	tween_balão.tween_callback(_esconder_balão)

func _esconder_balão() -> void:
	"""Esconde o balão completamente."""
	balao_fala.visible = false
	balao_fala.scale = Vector2.ONE
	balao_fala.modulate = Color.TRANSPARENT
	feedback_visivel = false
	texto_completo = ""
	texto_atual = ""
	label_fala.text = ""
	
	# Voltar para FOLLOW ou IDLE
	if player and _deve_seguir():
		_mudar_estado(Estado.FOLLOW)
	else:
		_mudar_estado(Estado.IDLE)
	
	feedback_escondido.emit()

func esconder_feedback() -> void:
	"""Esconde o feedback imediatamente (chamado externamente)."""
	if feedback_visivel:
		_animar_saida_balão()
		if timer_feedback:
			timer_feedback.stop()

func _criar_estilo_por_tipo(tipo: String, cor: Color) -> StyleBoxFlat:
	"""Cria um estilo de balão com cor de borda conforme o tipo."""
	var style = _criar_estilo_padrao()
	
	match tipo:
		"sucesso":
			style.bg_color = Color(0.05, 0.2, 0.05, 0.95)
			style.border_color = Color.GREEN
		"erro":
			style.bg_color = Color(0.2, 0.05, 0.05, 0.95)
			style.border_color = Color.RED
		"aviso":
			style.bg_color = Color(0.2, 0.15, 0.05, 0.95)
			style.border_color = Color.YELLOW
		_:
			style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
			style.border_color = Color.WHITE
	
	# Aplicar cor ao texto
	if label_fala:
		label_fala.add_theme_color_override("font_color", cor)
	
	return style

# =============================================================================
# FUNÇÕES PÚBLICAS DE MENSAGENS (MANTIDAS)
# =============================================================================

func gerar_elogio() -> String:
	"""Retorna um elogio aleatório."""
	return ELOGIOS[randi() % ELOGIOS.size()]

func gerar_dica() -> String:
	"""Retorna uma dica aleatória."""
	return DICAS[randi() % DICAS.size()]

func gerar_mensagem_disquete() -> String:
	"""Retorna uma mensagem sobre disquete."""
	return MENSAGENS_DISQUETE[randi() % MENSAGENS_DISQUETE.size()]

func gerar_mensagem_puzzle() -> String:
	"""Retorna uma mensagem sobre puzzle."""
	return MENSAGENS_PUZZLE[randi() % MENSAGENS_PUZZLE.size()]

func _gerar_explicacao_erros(resultado: Dictionary) -> String:
	"""Gera uma explicação detalhada dos erros."""
	var texto = "❌ " + resultado.get("topico", "Hmm...") + "\n"
	
	for erro in resultado.get("erros", []):
		if "Faltou" in erro:
			texto += "• " + erro.replace("Faltou: ", "") + "\n"
		elif "Não use" in erro:
			texto += "• " + erro.replace("Não use: ", "") + "\n"
		else:
			texto += "• " + erro + "\n"
	
	var dica = resultado.get("dica", "Tente novamente!")
	texto += "\n💡 " + dica
	
	return texto

# =============================================================================
# TIMER CALLBACKS
# =============================================================================

func _on_timer_feedback_timeout() -> void:
	"""Timer do feedback expirou."""
	if feedback_visivel:
		_animar_saida_balão()

func _on_timer_busca_player_timeout() -> void:
	"""Busca periódica do player."""
	if not player:
		encontrar_player()

# =============================================================================
# DETECÇÃO DE PLAYER
# =============================================================================

func encontrar_player() -> void:
	"""Busca o player na cena pelo grupo."""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		posicao_alvo = player.global_position
		print("🦕 DinoTeacher conectado ao player!")

# =============================================================================
# INTERFACE PÚBLICA
# =============================================================================

func get_direcao() -> int:
	"""Retorna a direção atual (1 direita, -1 esquerda)."""
	return direcao_atual

func get_posicao_alvo() -> Vector2:
	"""Retorna a posição alvo atual."""
	return posicao_alvo

func set_distancia_desejada(nova_distancia: float) -> void:
	"""Altera a distância que o NPC mantém do player."""
	distancia_desejada = max(30.0, nova_distancia)

func resetar_posicao() -> void:
	"""Reposiciona o NPC perto do player."""
	if player:
		var dir = 1
		if player.has_method("get_direcao"):
			dir = -player.get_direcao()
		global_position = player.global_position + Vector2(dir * distancia_desejada, 0)
		velocity = Vector2.ZERO
		_mudar_estado(Estado.FOLLOW)

# =============================================================================
# DEBUG
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	"""Retorna avisos de configuração para o editor."""
	var warnings = PackedStringArray()
	
	if not sprite:
		warnings.append("AnimatedSprite2D não encontrado!")
	if not balao_fala:
		warnings.append("BalaoFala (Panel) não encontrado!")
	if not collision:
		warnings.append("CollisionShape2D não encontrado!")
	
	return warnings

func _input(event: InputEvent) -> void:
	"""Tecla de debug (F3) para exibir estado."""
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			print("🦕 DinoTeacher - Estado atual:")
			print("   Estado: ", Estado.keys()[estado_atual])
			print("   Posição: ", global_position)
			print("   Alvo: ", posicao_alvo)
			print("   Player: ", player.global_position if player else "null")
			print("   Direção: ", direcao_atual)
			print("   Pulando: ", esta_pulando)
			print("   Velocidade: ", velocity)
