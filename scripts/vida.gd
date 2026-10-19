extends RigidBody2D
## Item de cura "Vida": cai com física real (RigidBody2D), colide com cenário e monstros,
## pousa e fica parado. Só o Player (grupo "player") consegue absorvê-lo, ao encostar na
## AreaDeteccao.
##
## Estrutura esperada da cena:
##   Vida (RigidBody2D)
##   ├─ CollisionShape2D          (corpo físico: colide com chão, paredes e monstros)
##   ├─ AreaDeteccao (Area2D)     (só detecta o Player para a coleta)
##   │   └─ CollisionShape2D
##   └─ TextureRect
##
## Usa a API que o player.gd já tem: curar(), get_vida_atual(), get_vida_maxima(), esta_morto.
## IMPORTANTE: mantenha a escala da raiz em (1, 1). RigidBody2D não suporta escala; para
## aumentar a imagem, escale o TextureRect.

## Emitido uma única vez, quando o item é coletado (útil para som, HUD etc.).
signal vida_coletada(quantidade: int)

const GRUPO_JOGADOR: StringName = &"player"
## Abaixo desta velocidade (px/s), em contato com o chão, o item é considerado parado.
const VELOCIDADE_PARADA: float = 25.0
## Quão "de frente" para o chão precisa ser o contato (|normal.y|) para contar como apoio.
const NORMAL_APOIO_MINIMA: float = 0.5
const ATRITO: float = 0.8
const MAX_CONTATOS: int = 4
const GRAVIDADE_PADRAO_FALLBACK: float = 980.0

@export_category("Cura")
## Quanto de vida o item devolve ao Player (a vida máxima do Player é respeitada em curar()).
@export var quantidade_cura: int = 25
## Se true, o item fica no lugar (sem ser coletado) enquanto o Player estiver com a vida cheia.
@export var coletar_somente_se_ferido: bool = true

@export_category("Queda")
## Desligue para o item ficar parado onde foi colocado.
@export var cair_ao_aparecer: bool = true
## Aceleração da gravidade em px/s². É convertida para o gravity_scale do corpo.
@export var gravidade: float = 900.0
@export var velocidade_queda_maxima: float = 700.0
## 0 = pousa sem quicar. Valores maiores fazem um pequeno quique ao cair.
@export_range(0.0, 0.9) var elasticidade: float = 0.3
## Se cair mais que isso sem pousar, o item é removido (evita cair para sempre).
@export var distancia_maxima_queda: float = 1500.0

@export_category("Efeito de coleta")
@export var duracao_efeito: float = 0.25
## Quanto a imagem sobe enquanto some.
@export var altura_efeito: float = 16.0

var _coletada: bool = false
var _pousou: bool = false
var _y_inicial: float = 0.0

@onready var _area: Area2D = $AreaDeteccao
@onready var _imagem: TextureRect = $TextureRect


func _ready() -> void:
	_y_inicial = global_position.y
	_configurar_corpo()
	# Sem queda: o corpo nasce congelado (estático) e permanece onde foi colocado.
	_pousou = not cair_ao_aparecer
	freeze = _pousou


func _configurar_corpo() -> void:
	lock_rotation = true
	can_sleep = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY # evita atravessar chão fino em alta velocidade
	contact_monitor = true # necessário para ler contatos em _integrate_forces
	max_contacts_reported = MAX_CONTATOS
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	gravity_scale = gravidade / _gravidade_padrao_do_projeto()

	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.bounce = elasticidade
	material.friction = ATRITO
	physics_material_override = material


func _gravidade_padrao_do_projeto() -> float:
	var valor: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", GRAVIDADE_PADRAO_FALLBACK))
	return valor if valor > 0.0 else GRAVIDADE_PADRAO_FALLBACK


func _physics_process(_delta: float) -> void:
	if _coletada:
		return

	if _caiu_longe_demais():
		push_warning("Vida: caiu %.0f px sem pousar; removida. Confira as camadas de colisão do chão." % distancia_maxima_queda)
		queue_free()
		return

	# Verifica a cada frame de física quem está sobre o item. Assim, se o Player chegar com a
	# vida cheia e depois levar dano a coleta acontece na hora certa — body_entered só dispara
	# na entrada e perderia esse caso.
	for corpo in _area.get_overlapping_bodies():
		if _tentar_coletar(corpo):
			return


## Único ponto que mexe na velocidade do corpo: limita a queda e detecta o pouso.
func _integrate_forces(estado: PhysicsDirectBodyState2D) -> void:
	if estado.linear_velocity.y > velocidade_queda_maxima:
		estado.linear_velocity.y = velocidade_queda_maxima

	if _coletada or _pousou:
		return
	if _esta_parado_no_chao(estado):
		_pousou = true
		# Congela como corpo estático: fica no lugar e continua bloqueando monstros.
		set_deferred(&"freeze", true)


func _esta_parado_no_chao(estado: PhysicsDirectBodyState2D) -> bool:
	if estado.linear_velocity.length() > VELOCIDADE_PARADA:
		return false
	for i in estado.get_contact_count():
		# Parado em cima de um monstro não conta: ele pode sair e o item ficaria flutuando.
		if estado.get_contact_collider_object(i) is CharacterBody2D:
			continue
		if absf(estado.get_contact_local_normal(i).y) >= NORMAL_APOIO_MINIMA:
			return true
	return false


func _caiu_longe_demais() -> bool:
	return not _pousou and global_position.y - _y_inicial > distancia_maxima_queda


func _tentar_coletar(corpo: Node) -> bool:
	# Monstros (e qualquer coisa fora do grupo) nunca coletam nem recebem cura.
	if not corpo.is_in_group(GRUPO_JOGADOR):
		return false
	if not corpo.has_method(&"curar"):
		push_error("Vida: o Player não tem o método 'curar(quantidade)'.")
		return false
	if corpo.get(&"esta_morto") == true:
		return false
	if coletar_somente_se_ferido and corpo.has_method(&"get_vida_atual") and corpo.has_method(&"get_vida_maxima"):
		if int(corpo.call(&"get_vida_atual")) >= int(corpo.call(&"get_vida_maxima")):
			return false

	_coletada = true # primeiro: garante que a coleta só acontece uma vez
	_desativar_fisica()
	corpo.call(&"curar", quantidade_cura)
	vida_coletada.emit(quantidade_cura)
	_efeito_e_remover()
	return true


## Depois de coletado o item não interage mais com nada. Deferred porque pode ser chamado
## durante o passo de física.
func _desativar_fisica() -> void:
	set_deferred(&"freeze", true)
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	_area.set_deferred(&"monitoring", false)
	_area.set_deferred(&"monitorable", false)


func _efeito_e_remover() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_imagem, "modulate:a", 0.0, duracao_efeito)
	tween.tween_property(_imagem, "position:y", _imagem.position.y - altura_efeito, duracao_efeito)
	await tween.finished
	queue_free()
