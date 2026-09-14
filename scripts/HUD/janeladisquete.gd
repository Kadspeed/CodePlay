# scripts/janela_disquete.gd
extends Panel

signal fechou()

# ============ NÓS ============
@onready var botao_fechar: TextureButton = $Botao
@onready var titulo_label: Label = $Titulo
@onready var conteudo_richtext: RichTextLabel = $Conteudo

# ============ DADOS ============
var item_atual: Dictionary = {}

# ============ INICIALIZAÇÃO ============
func _ready():
	visible = false

	if botao_fechar:
		botao_fechar.pressed.connect(_on_botao_fechar_pressed)

	if conteudo_richtext:
		conteudo_richtext.bbcode_enabled = true
		conteudo_richtext.scroll_following = true
		conteudo_richtext.scroll_active = true

		conteudo_richtext.add_theme_color_override("default_color", Color(0, 1, 0))
		conteudo_richtext.add_theme_font_size_override("normal_font_size", 16)

		conteudo_richtext.text = "[color=#00ff00]Aguardando seleção...[/color]"

	if titulo_label:
		titulo_label.add_theme_color_override("font_color", Color(0, 1, 0))
		titulo_label.add_theme_font_size_override("font_size", 20)
		titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo_label.text = "📦 DISQUETE"

	print("✅ JanelaDisquete inicializada (escondida)")

# ============ ABRIR JANELA ============
func abrir(item_data: Dictionary):
	"""
	Abre a janela com os dados já prontos do item.
	Espera um Dictionary no formato:
	{
		"nome": "disquete_azul",
		"titulo": "Variáveis",
		"texto": "Conteúdo do disquete...",
		"icone": Texture2D (opcional)
	}
	"""
	var nome_item: String = item_data.get("nome", "desconhecido")
	print("[JANELA] abrir() chamado para: ", nome_item)

	if item_data.is_empty():
		print("[JANELA] ERRO: tentativa de abrir janela com dados vazios")
		return

	item_atual = item_data

	if titulo_label:
		titulo_label.text = item_data.get("titulo", "Disquete")

	if conteudo_richtext:
		var texto = item_data.get("texto", "Sem informações disponíveis.")
		conteudo_richtext.text = "[color=#00ff00]" + texto + "[/color]"

	visible = true
	show()

	await get_tree().process_frame
	if conteudo_richtext:
		conteudo_richtext.text = conteudo_richtext.text

	print("[JANELA] Janela aberta: ", nome_item)

# ============ FECHAR JANELA ============
func fechar():
	visible = false
	item_atual = {}
	fechou.emit()
	print("[JANELA] Janela fechada")

func _on_botao_fechar_pressed():
	fechar()

# ============ FUNÇÕES AUXILIARES ============
func esta_aberta() -> bool:
	return visible

func get_item_atual() -> Dictionary:
	return item_atual

func get_disquete_atual() -> Dictionary:
	return get_item_atual()
