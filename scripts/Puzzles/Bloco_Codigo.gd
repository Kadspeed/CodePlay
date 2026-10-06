# scripts/bloco_codigo.gd
extends Control

# ============ SINAIS ============
signal bloco_clicado(bloco: Node)

# ============ VARIÁVEIS EXPORTADAS ============
@export var texto_bloco: String = "Bloco"
@export var tipo_bloco: String = "sintaxe"  # sintaxe | operador | valor
@export var valor_bloco: String = ""

# ============ VARIÁVEIS INTERNAS ============
var selecionado: bool = false

# ============ NÓS ============
@onready var texture_rect: TextureRect = $TextureRect
@onready var label: Label = $Label

# ============ CORES ============
const COR_TEXTO: Color = Color(0, 1, 0)  # #00FF00 - Verde estilo terminal
const COR_SELECIONADO: Color = Color(1, 0.8, 0.2, 1)  # Amarelo dourado

# ============ INICIALIZAÇÃO ============
func _ready():
	# Configurar o texto do bloco
	if label:
		label.text = texto_bloco
		label.add_theme_color_override("font_color", COR_TEXTO)
		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Se valor_bloco estiver vazio, usar o texto como valor
	if valor_bloco.is_empty():
		valor_bloco = texto_bloco
	
	# Configurar o bloco para receber clique
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	
	# Configurar os filhos para não bloquear o mouse
	if texture_rect:
		texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	if label:
		label.mouse_filter = MOUSE_FILTER_IGNORE
	
	# Configurar tamanho mínimo
	custom_minimum_size = Vector2(100, 40)
	
	print("✅ Bloco pronto: ", texto_bloco, " (", tipo_bloco, ": ", valor_bloco, ")")

# ============ DETECÇÃO DE CLIQUE ============
func _gui_input(event: InputEvent):
	if not event is InputEventMouseButton:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_clicado()

# ============ FUNÇÃO DE CLIQUE ============
func _on_clicado():
	print("🖱️ Bloco clicado: ", texto_bloco)
	
	# Efeito visual de clique
	_selecionar()
	
	# Emitir sinal com a própria referência
	bloco_clicado.emit(self)

# ============ EFEITOS VISUAIS ============
func _selecionar():
	selecionado = true
	modulate = COR_SELECIONADO
	scale = Vector2(1.05, 1.05)

func _deselecionar():
	selecionado = false
	modulate = Color.WHITE
	scale = Vector2(1, 1)

# ============ FUNÇÕES PÚBLICAS ============

# Getters principais
func get_tipo() -> String:
	return tipo_bloco

func get_texto() -> String:
	return texto_bloco

func get_valor() -> String:
	return valor_bloco

# Setters
func definir_tipo(novo_tipo: String):
	tipo_bloco = novo_tipo

func definir_texto(novo_texto: String):
	texto_bloco = novo_texto
	if label:
		label.text = novo_texto

func definir_valor(novo_valor: String):
	valor_bloco = novo_valor

# Funções auxiliares
func get_bloco_id() -> int:
	return get_instance_id()

# 🔥 CORRIGIDO: Renomeado para evitar conflito com a variável
func is_selecionado() -> bool:
	return selecionado

# Resetar estado visual
func resetar_visual():
	_deselecionar()

# ============ DEBUG ============
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if not texture_rect:
		warnings.append("TextureRect não encontrado!")
	
	if not label:
		warnings.append("Label não encontrado!")
	
	if tipo_bloco.is_empty():
		warnings.append("tipo_bloco não configurado! Use: sintaxe, operador ou valor")
	
	if valor_bloco.is_empty():
		warnings.append("valor_bloco não configurado! Defina o valor real do bloco")
	
	return warnings
