extends Control

# ============================================================
# PUZZLE_ARRAYS — CodePlay
# Desafio: montar `let frutas = ["Maçã", "Banana", "Uva"];`
# e acessar `frutas[1]` (console.log(frutas[1]) -> "Banana")
#
# Mesma lógica estrutural do Puzzle de FUNÇÕES:
# - array guarda o conteúdo dos slots
# - dicionário relaciona botão -> valor
# - clique na opção -> primeiro slot vazio
# - opção usada -> disabled
# - clique no slot preenchido -> remove somente aquele conteúdo
# - opção removida -> volta a ficar disponível
# - os outros slots nunca se movem
# - validação separada para TESTAR e EXECUTAR
# - sinal desafio_concluido, sem emissão duplicada
#
# ESTÉTICA: copiada 1:1 da estrutura visual do Puzzle_cidade (Puzzle de
# FUNÇÕES) — mesmas funções (_caixa, _caixa_foco, _definir_estilos,
# _estilizar_botao_padrao, _estilizar_titulo, _colorir_label_titulo,
# _atualizar_estilo_slot), só trocando a identidade AZUL pela identidade
# VERDE. Nenhuma posição, tamanho, âncora, texto ou nome de nó foi
# alterado — a estética é aplicada inteiramente por código
# (StyleBoxFlat + theme overrides), como no Puzzle de FUNÇÕES.
# ============================================================

signal desafio_concluido

# ------------------------------------------------------------
# REFERÊNCIAS DIRETAS DA ÁRVORE DA CENA (sem @export)
# ------------------------------------------------------------

@onready var slot_fruta1: Button = $PainelCodigo/SlotFruta1
@onready var slot_fruta2: Button = $PainelCodigo/SlotFruta2
@onready var slot_fruta3: Button = $PainelCodigo/SlotFruta3
@onready var slot_indice: Button = $PainelCodigo/SlotIndice

@onready var opcao_maca: Button = $PainelOpcoes/Maca
@onready var opcao_banana: Button = $PainelOpcoes/Banana
@onready var opcao_uva: Button = $PainelOpcoes/Uva
@onready var opcao_carro: Button = $PainelOpcoes/Carro
@onready var opcao_pedra: Button = $PainelOpcoes/Pedra
@onready var opcao_casa: Button = $PainelOpcoes/Casa

@onready var opcao_zero: Button = $PainelOpcoes/Zero
@onready var opcao_um: Button = $PainelOpcoes/Um
@onready var opcao_dois: Button = $PainelOpcoes/Dois

@onready var btn_testar: Button = $Testar
@onready var btn_executar: Button = $Executar

# TextoFeedback e Dica podem ser Label ou RichTextLabel na cena;
# não tipamos estritamente para funcionar com qualquer um dos dois.
@onready var texto_feedback = $PainelFeedback/TextoFeedback
@onready var dica = $PainelDica/Dica

# TextoObjetivo também pode ser Label ou RichTextLabel na cena.
@onready var texto_objetivo = $PainelObjetivo/TextoObjetivo

# ------------------------------------------------------------
# ESTADO INTERNO
# ------------------------------------------------------------

var slots_frutas: Array[Button] = []
var opcoes_frutas: Array[Button] = []
var opcoes_indices: Array[Button] = []

# slot_fruta_valor[i] == "" significa slot vazio
var slot_fruta_valor: Array[String] = ["", "", ""]
var indice_valor: String = ""  # "" significa SlotIndice vazio

# Dicionário botão -> valor que ele representa (lido do próprio .text)
var opcao_valor: Dictionary = {}

# Dicionário texto do botão de índice -> número correspondente
var indice_numero: Dictionary = {}

var desafio_ja_concluido: bool = false

const TEXTO_DICA := "Um array pode armazenar vários valores em uma única variável.

Exemplo:
let cores = [\"Azul\", \"Verde\", \"Vermelho\"];

Os elementos de um array possuem índices que começam em 0:
cores[0] → primeiro elemento (\"Azul\")
cores[1] → segundo elemento (\"Verde\")
cores[2] → terceiro elemento (\"Vermelho\")

Para mostrar um elemento no console, use:
console.log(nomeDoArray[índice]);"

## Objetivo principal exibido em PainelObjetivo/TextoObjetivo. É a
## informação mais importante desse painel — nada mais deve substituí-la
## ou escondê-la; qualquer conteúdo complementar (curiosidades) deve vir
## junto/abaixo dela, nunca no lugar dela.
const TEXTO_OBJETIVO := "Crie um array chamado `frutas` com três frutas e mostre a segunda fruta no console."


# --- Paleta visual (PRETO + VERDE + BRANCO) ----------------------------------
# Mesmo papel visual das cores do Puzzle de FUNÇÕES (que usava azul),
# só que com identidade verde para o Puzzle_Arrays.

const COR_FUNDO := Color("000000")
const COR_PAINEL := Color("020a06")
const COR_BOTAO := Color("05100a")
const COR_VERDE := Color("4fd68c")            # verde principal (bordas)
const COR_VERDE_BRILHO := Color("baffe0")     # verde mais brilhante (hover/focus)
const COR_VERDE_APAGADO := Color("2a8f63")    # verde mais discreto (slot vazio, desabilitado)
const COR_VERDE_ESCURO := Color("05190f")     # tom escuro para o hover parcial
const COR_VERDE_FORTE := Color("0a8a52")      # verde mais forte/escuro (pressed)
const COR_TEXTO := Color("f2fff8")
const COR_TEXTO_DESABILITADO := Color("5f9678")

const RAIO_BORDA := 6


func _ready() -> void:
	slots_frutas = [slot_fruta1, slot_fruta2, slot_fruta3]
	opcoes_frutas = [opcao_maca, opcao_banana, opcao_uva, opcao_carro, opcao_pedra, opcao_casa]
	opcoes_indices = [opcao_zero, opcao_um, opcao_dois]

	_registrar_valores_opcoes()
	_conectar_sinais()
	_limpar_slots_visual()
	_aplicar_estetica()

	dica.text = TEXTO_DICA
	texto_objetivo.text = TEXTO_OBJETIVO
	_set_feedback("Monte o array e experimente diferentes índices.")


## Fundo geral preto. Desenhado pelo próprio Control raiz (fica atrás dos
## filhos), então não precisa de nenhum nó novo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)


func _registrar_valores_opcoes() -> void:
	for opcao in opcoes_frutas:
		opcao_valor[opcao] = opcao.text

	indice_numero[opcao_zero.text] = 0
	indice_numero[opcao_um.text] = 1
	indice_numero[opcao_dois.text] = 2


func _conectar_sinais() -> void:
	for opcao in opcoes_frutas:
		opcao.pressed.connect(_on_opcao_fruta_pressed.bind(opcao))

	for i in range(slots_frutas.size()):
		slots_frutas[i].pressed.connect(_on_slot_fruta_pressed.bind(i))

	for opcao in opcoes_indices:
		opcao.pressed.connect(_on_opcao_indice_pressed.bind(opcao))

	slot_indice.pressed.connect(_on_slot_indice_pressed)

	btn_testar.pressed.connect(_on_testar_pressed)
	btn_executar.pressed.connect(_on_executar_pressed)


func _limpar_slots_visual() -> void:
	slot_fruta1.text = ""
	slot_fruta2.text = ""
	slot_fruta3.text = ""
	slot_indice.text = ""


# --- Estética (tudo por StyleBoxFlat + theme overrides) ------------------------
# Mesma estrutura de funções do Puzzle de FUNÇÕES (_caixa, _caixa_foco,
# _definir_estilos, _estilizar_botao_padrao, _estilizar_titulo,
# _colorir_label_titulo, _atualizar_estilo_slot), só usando COR_VERDE* em
# vez de COR_AZUL*.

## Aplica a identidade visual inteira. Não mexe em posição, tamanho ou estrutura.
func _aplicar_estetica() -> void:
	# Redesenha o fundo preto quando a cena for redimensionada.
	resized.connect(queue_redraw)
	queue_redraw()

	# Texto principal branco em todos os Labels da cena, com quebra
	# automática de linha para nenhum texto ultrapassar a largura do
	# bloco onde está (sem alterar tamanho/posição de nada).
	for no in find_children("*", "Label", true, false):
		no.add_theme_color_override("font_color", COR_TEXTO)
		no.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Dica, TextoFeedback e TextoObjetivo podem ser RichTextLabel — o loop
	# acima só pega Label, então garantimos a cor aqui também, seja qual
	# for o tipo de cada um.
	_colorir_texto_generico(dica, COR_TEXTO)
	_colorir_texto_generico(texto_feedback, COR_TEXTO)
	_colorir_texto_generico(texto_objetivo, COR_TEXTO)

	# Painéis: fundo escuro levemente esverdeado, borda verde arredondada, leve brilho.
	for nome in ["PainelCodigo", "PainelObjetivo", "PainelOpcoes", "PainelDica", "PainelFeedback"]:
		var painel := get_node_or_null(nome) as Control
		if painel != null:
			painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_VERDE, 2, 6))

	# Títulos (Labels ou áreas delimitadas de título). get_node_or_null faz
	# _estilizar_titulo simplesmente não fazer nada quando o caminho não
	# existir na cena, então é seguro tentar os caminhos mais comuns.
	_estilizar_titulo("Titulo", true)
	_estilizar_titulo("PainelCodigo/TituloArea")
	_estilizar_titulo("PainelObjetivo/TituloObjetivo")
	_estilizar_titulo("PainelOpcoes/TituloArea")
	_estilizar_titulo("PainelDica/TituloArea")
	_estilizar_titulo("PainelFeedback/TituloArea")

	# Botões de opção (frutas e índices).
	for opcao in opcoes_frutas:
		_estilizar_botao_padrao(opcao)
	for opcao in opcoes_indices:
		_estilizar_botao_padrao(opcao)

	# Botões Testar e Executar.
	_estilizar_botao_padrao(btn_testar)
	_estilizar_botao_padrao(btn_executar)

	# Slots (aparência depende de estarem vazios ou preenchidos). No início
	# todos os slots estão vazios (slot_fruta_valor e indice_valor == "").
	for slot in slots_frutas:
		_atualizar_estilo_slot(slot, false)
	_atualizar_estilo_slot(slot_indice, false)


## Aplica a cor de texto certa dependendo do tipo do nó (Label ou
## RichTextLabel) e garante quebra automática de linha horizontal, para o
## texto nunca ultrapassar a largura do bloco/painel onde está — sem mexer
## em tamanho, posição ou layout de nada.
func _colorir_texto_generico(no: Node, cor: Color) -> void:
	if no is Label:
		no.add_theme_color_override("font_color", cor)
		no.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif no is RichTextLabel:
		no.add_theme_color_override("default_color", cor)
		# RichTextLabel também tem autowrap_mode (Godot 4.x) — garante que o
		# texto quebre pela largura disponível em vez de estourar o painel.
		no.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Se o texto ocupar mais linhas do que a altura do painel comporta,
		# ele passa a rolar verticalmente DENTRO do próprio bloco, em vez de
		# vazar pra fora dele.
		no.scroll_active = true


## Cria um StyleBoxFlat.
## - largura: espessura da borda em todos os lados;
## - brilho: tamanho da sombra verde (efeito de luz); 0 = sem brilho;
## - largura_esq / largura_baixo: espessura extra só nesses lados (faixa parcial);
## - margem_h / margem_v: margens internas (>= 0 para fixar; -1 mantém o padrão).
func _caixa(
		fundo: Color,
		borda: Color,
		largura: int = 2,
		brilho: int = 0,
		largura_esq: int = -1,
		largura_baixo: int = -1,
		margem_h: int = -1,
		margem_v: int = -1
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(largura)
	if largura_esq >= 0:
		sb.border_width_left = largura_esq
	if largura_baixo >= 0:
		sb.border_width_bottom = largura_baixo
	sb.set_corner_radius_all(RAIO_BORDA)
	if brilho > 0:
		sb.shadow_color = Color(COR_VERDE.r, COR_VERDE.g, COR_VERDE.b, 0.35)
		sb.shadow_size = brilho
		sb.shadow_offset = Vector2.ZERO
	if margem_h >= 0:
		sb.content_margin_left = margem_h
		sb.content_margin_right = margem_h
	if margem_v >= 0:
		sb.content_margin_top = margem_v
		sb.content_margin_bottom = margem_v
	return sb


## Contorno de foco: só a borda, sem preencher o botão.
func _caixa_foco() -> StyleBoxFlat:
	var sb := _caixa(Color(0, 0, 0, 0), COR_VERDE_BRILHO, 2)
	sb.draw_center = false
	return sb


## Aplica os estilos de cada estado e as cores de texto a um Button.
func _definir_estilos(
		botao: Button,
		normal: StyleBox,
		hover: StyleBox,
		pressed: StyleBox,
		focus: StyleBox,
		disabled: StyleBox,
		cor_texto: Color
) -> void:
	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressed)
	botao.add_theme_stylebox_override("hover_pressed", pressed)
	botao.add_theme_stylebox_override("focus", focus)
	botao.add_theme_stylebox_override("disabled", disabled)

	for nome_cor in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color"
	]:
		botao.add_theme_color_override(nome_cor, cor_texto)
	botao.add_theme_color_override("font_disabled_color", COR_TEXTO_DESABILITADO)


## Botões de opção, Testar e Executar.
## Hover PARCIAL: o botão continua escuro, mas ganha borda mais brilhante,
## faixa mais grossa à esquerda e embaixo e um tom verde bem escuro no fundo.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_VERDE, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_VERDE_ESCURO, COR_VERDE_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_VERDE_FORTE, COR_VERDE, 2, 0, -1, -1, 10, 6)
	var disabled := _caixa(COR_FUNDO, COR_VERDE_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


## Título: fundo preto, borda verde arredondada, texto branco.
## O título principal ("Titulo") ganha borda mais grossa/brilhante, brilho e texto verde-claro.
## Funciona se o nó for um Label ou uma área (Panel/PanelContainer) com Label dentro.
func _estilizar_titulo(caminho: NodePath, destaque: bool = false) -> void:
	var no := get_node_or_null(caminho) as Control
	if no == null:
		return

	var borda := COR_VERDE_BRILHO if destaque else COR_VERDE
	var largura := 3 if destaque else 2
	var brilho := 12 if destaque else 0
	var caixa := _caixa(COR_FUNDO, borda, largura, brilho, -1, -1, 10, 2)
	var cor_texto := COR_VERDE_BRILHO if destaque else COR_TEXTO

	if no is Label:
		no.add_theme_stylebox_override("normal", caixa)
		_colorir_label_titulo(no as Label, cor_texto, destaque)
	else:
		no.add_theme_stylebox_override("panel", caixa)
		for filho in no.find_children("*", "Label", true, false):
			_colorir_label_titulo(filho as Label, cor_texto, destaque)


func _colorir_label_titulo(label: Label, cor_texto: Color, destaque: bool) -> void:
	label.add_theme_color_override("font_color", cor_texto)
	if destaque:
		label.add_theme_color_override("font_outline_color", COR_VERDE_FORTE)
		label.add_theme_constant_override("outline_size", 3)


## Slot vazio: preto, borda verde fina/discreta.
## Slot preenchido: preto, borda verde grossa com brilho e texto em verde-claro.
## O hover do slot preenchido usa o mesmo destaque parcial dos botões.
func _atualizar_estilo_slot(slot: Button, preenchido: bool) -> void:
	if not preenchido:
		var normal := _caixa(COR_FUNDO, COR_VERDE_APAGADO, 1, 0, -1, -1, 10, 6)
		var hover := _caixa(COR_FUNDO, COR_VERDE, 2, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)
	else:
		var normal := _caixa(COR_FUNDO, COR_VERDE, 3, 8, -1, -1, 10, 6)
		var hover := _caixa(COR_VERDE_ESCURO, COR_VERDE_BRILHO, 3, 10, 7, 6, 10, 6)
		var pressed := _caixa(COR_VERDE_FORTE, COR_VERDE, 3, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_VERDE_BRILHO)


# ------------------------------------------------------------
# FRUTAS
# ------------------------------------------------------------

func _on_opcao_fruta_pressed(opcao: Button) -> void:
	if opcao.disabled:
		return

	# primeiro slot vazio, na ordem SlotFruta1 -> SlotFruta2 -> SlotFruta3
	for i in range(slot_fruta_valor.size()):
		if slot_fruta_valor[i] == "":
			slot_fruta_valor[i] = opcao_valor[opcao]
			slots_frutas[i].text = opcao_valor[opcao]
			_atualizar_estilo_slot(slots_frutas[i], true)
			opcao.disabled = true
			return
	# se todos os slots já estiverem preenchidos, o clique não faz nada


func _on_slot_fruta_pressed(indice_slot: int) -> void:
	if slot_fruta_valor[indice_slot] == "":
		return  # slot já vazio, nada a fazer

	var valor_removido: String = slot_fruta_valor[indice_slot]

	# esvazia SOMENTE esse slot; os demais permanecem intactos
	slot_fruta_valor[indice_slot] = ""
	slots_frutas[indice_slot].text = ""
	_atualizar_estilo_slot(slots_frutas[indice_slot], false)

	var opcao_original := _encontrar_opcao_fruta_por_valor(valor_removido)
	if opcao_original != null:
		opcao_original.disabled = false


func _encontrar_opcao_fruta_por_valor(valor: String) -> Button:
	for opcao in opcoes_frutas:
		if opcao_valor[opcao] == valor:
			return opcao
	return null


# ------------------------------------------------------------
# ÍNDICE
# ------------------------------------------------------------

func _on_opcao_indice_pressed(opcao: Button) -> void:
	if opcao.disabled:
		return

	# só existe um SlotIndice: libera a opção anterior antes de trocar
	if indice_valor != "":
		var opcao_anterior := _encontrar_opcao_indice_por_texto(indice_valor)
		if opcao_anterior != null:
			opcao_anterior.disabled = false

	indice_valor = opcao.text
	slot_indice.text = opcao.text
	_atualizar_estilo_slot(slot_indice, true)
	opcao.disabled = true


func _on_slot_indice_pressed() -> void:
	if indice_valor == "":
		return

	var opcao := _encontrar_opcao_indice_por_texto(indice_valor)
	if opcao != null:
		opcao.disabled = false

	indice_valor = ""
	slot_indice.text = ""
	_atualizar_estilo_slot(slot_indice, false)


func _encontrar_opcao_indice_por_texto(texto: String) -> Button:
	for opcao in opcoes_indices:
		if opcao.text == texto:
			return opcao
	return null


# ------------------------------------------------------------
# TESTAR (experimentar índices, não exige a solução correta)
# ------------------------------------------------------------

func _on_testar_pressed() -> void:
	if indice_valor == "" or not indice_numero.has(indice_valor):
		_set_feedback("Selecione um índice antes de testar.")
		return

	var idx: int = indice_numero[indice_valor]

	if idx < 0 or idx >= slot_fruta_valor.size() or slot_fruta_valor[idx] == "":
		_set_feedback("Preencha a fruta correspondente a esse índice antes de testar.")
		return

	var resultado: String = slot_fruta_valor[idx]
	_set_feedback("Resultado: %s" % resultado)


# ------------------------------------------------------------
# EXECUTAR (valida o desafio principal)
# ------------------------------------------------------------

func _on_executar_pressed() -> void:
	if slot_fruta_valor[0] == "" or slot_fruta_valor[1] == "" or slot_fruta_valor[2] == "" or indice_valor == "":
		_set_feedback("Preencha todos os campos antes de executar.")
		return

	# O desafio não exige nenhuma fruta específica em nenhum slot — os três
	# valores são livres. A única coisa que precisa estar correta é o
	# ÍNDICE: a "segunda fruta" do array corresponde à posição 1.
	if not indice_numero.has(indice_valor):
		_set_feedback("Preencha todos os campos antes de executar.")
		return

	var idx: int = indice_numero[indice_valor]

	if idx == 1:
		_set_feedback("Correto! O índice 1 acessa a segunda posição do array.")
		if not desafio_ja_concluido:
			desafio_ja_concluido = true
			desafio_concluido.emit()
	else:
		_set_feedback("Código incorreto! Para mostrar a segunda posição, use o índice correspondente a ela.")


# ------------------------------------------------------------
# HELPER DE FEEDBACK
# ------------------------------------------------------------

func _set_feedback(mensagem: String) -> void:
	texto_feedback.text = mensagem
