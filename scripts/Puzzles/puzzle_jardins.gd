extends Control
## Puzzle de Arrays — Jardins Mecânicos (Godot 4.x | GDScript)
##
## Código conceitual:
##   let frutas = ["Maçã", "Banana", "Uva"];
##   console.log(frutas[1]);   // "Banana"
##
## COMO FUNCIONA
## - O jogador monta um array de 3 frutas clicando nas opções (sempre no primeiro
##   slot vazio) e escolhe UM índice (0, 1 ou 2) para a consulta.
## - Clicar em um slot preenchido remove só aquele elemento; os demais não se movem
##   e a opção removida volta a ficar disponível.
## - O ESTADO INTERNO é a única fonte de verdade (_fruta_no_slot e _indice_escolhido).
##   Toda a interface (textos, estilos, opções desabilitadas) é redesenhada a partir
##   dele em _sincronizar_interface(), então não há como ficar inconsistente.
## - Testar: mostra o elemento que o índice escolhido acessa. NUNCA conclui.
## - Executar: valida (campos, frutas válidas, índice válido, índice == 1) e conclui,
##   emitindo desafio_concluido UMA vez. Qualquer combinação de 3 frutas é aceita.
## - Limpar / resetar_puzzle(): restaura tudo e permite resolver de novo.
##
## A validação usa o NOME DO NODE da opção (Maca, Banana, Uva, Carro, Pedra, Casa),
## nunca o texto visível, nem mensagens, nem cores.

signal desafio_concluido

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO DO DESAFIO
# ---------------------------------------------------------------------------
const NOME_ARRAY := "frutas"
const QTD_SLOTS := 3
const INDICE_ALVO := 1                       # segunda posição
const PLACEHOLDER := "___"
const NOME_DESAFIO := "ARRAY"
const NOME_FASE := "Jardins Mecânicos"

# Node.name das opções que são frutas (o resto são distratores).
const FRUTAS_VALIDAS: Array[String] = ["Maca", "Banana", "Uva"]
# Node.name do botão de índice -> número que ele representa.
const INDICES := {"Zero": 0, "Um": 1, "Dois": 2}
const ORDINAIS: Array[String] = ["primeira", "segunda", "terceira"]

const TEXTO_OBJETIVO := "Objetivo: crie um array chamado frutas com três frutas e mostre a segunda fruta no console."
const TEXTO_DICA := "Os índices de um array começam em zero. O primeiro elemento está no índice 0, o segundo no índice 1 e o terceiro no índice 2.\n\nExemplo:\nlet cores = [\"Azul\", \"Verde\", \"Vermelho\"];\ncores[0] → \"Azul\"\ncores[1] → \"Verde\"\ncores[2] → \"Vermelho\"\n\nPara mostrar um elemento:\nconsole.log(nomeDoArray[índice]);"

# ---------------------------------------------------------------------------
# ESTÉTICA — PALETA (PRETO + AMARELO JARDINS MECÂNICOS + BRANCO)
# ---------------------------------------------------------------------------
const COR_FUNDO := Color("000000")
const COR_PAINEL := Color("0d0e06")
const COR_BOTAO := Color("121208")
const COR_TERMINAL := Color("080903")

const COR_AMARELO_MUITO_ESCURO := Color("1d1c07")
const COR_AMARELO_ESCURO := Color("363308")
const COR_AMARELO_APAGADO := Color("6b672c")
const COR_AMARELO_FORTE := Color("7a7010")
const COR_AMARELO_MEDIO := Color("a89f22")
const COR_AMARELO := Color("c9bd33")
const COR_AMARELO_INTENSO := Color("dccf3d")
const COR_AMARELO_VIVO := Color("e6d84f")
const COR_AMARELO_BRILHO := Color("fff3a0")

const COR_TEXTO := Color("edf0df")
const COR_TEXTO_DESABILITADO := Color("8a8b70")

# Categorias de opção (ambas na família amarela).
const COR_FRUTA := Color("e6d84f")
const COR_INDICE := Color("ffb938")

const RAIO_BORDA := 6
const RAIO_OPCAO := 8
const RAIO_TERMINAL := 4
const ALFA_BRILHO := 0.35

const MARGEM_H_BOTAO := 8
const MARGEM_V_BOTAO := 4
const MARGEM_H_PAINEL := 12
const MARGEM_V_PAINEL := 8

const TAMANHO_FONTE_CODIGO := 17
const TAMANHO_FONTE_BOTAO := 16
const TAMANHO_FONTE_TEXTO := 15

# ---------------------------------------------------------------------------
# NODES (todos por nome único — "Access as Unique Name" na cena)
# ---------------------------------------------------------------------------
@onready var janela_puzzle: Panel = %JanelaPuzzle
@onready var barra_titulo: PanelContainer = %BarraTitulo
@onready var titulo: Label = %Titulo
@onready var indicador_desafio: Label = %IndicadorDesafio
@onready var chip_array: Label = %ChipArray

@onready var painel_codigo: PanelContainer = %PainelCodigo
@onready var cabecalho_codigo: Label = %CabecalhoCodigo
@onready var slot_fruta1: Button = %SlotFruta1
@onready var slot_fruta2: Button = %SlotFruta2
@onready var slot_fruta3: Button = %SlotFruta3
@onready var slot_indice: Button = %SlotIndice

@onready var painel_opcoes: PanelContainer = %PainelOpcoes
@onready var titulo_opcoes: Label = %TituloOpcoes
@onready var titulo_indices: Label = %TituloIndices
@onready var container_frutas: Container = %OpcoesFrutas
@onready var container_indices: Container = %OpcoesIndices

@onready var painel_dica: PanelContainer = %PainelDica
@onready var titulo_dica: Label = %TituloDica
@onready var dica: RichTextLabel = %Dica

@onready var painel_botoes: PanelContainer = %PainelBotoes
@onready var btn_testar: Button = %Testar
@onready var btn_limpar: Button = %Limpar
@onready var btn_executar: Button = %Executar

@onready var painel_feedback: PanelContainer = %PainelFeedback
@onready var texto_feedback: RichTextLabel = %TextoFeedback

# ---------------------------------------------------------------------------
# ESTADO (fonte de verdade)
# ---------------------------------------------------------------------------
# Node.name da opção que está em cada slot ("" = vazio). Posição fixa: nunca desloca.
var _fruta_no_slot: Array[String] = []
# Índice escolhido para a consulta (-1 = nenhum).
var _indice_escolhido: int = -1
var desafio_resolvido: bool = false

var _slots_frutas: Array[Button] = []
var _opcoes_frutas: Dictionary = {}    # Node.name -> Button
var _opcoes_indices: Dictionary = {}   # número -> Button

var _fonte_mono: SystemFont


func _ready() -> void:
	_fonte_mono = SystemFont.new()
	_fonte_mono.font_names = ["Consolas", "Courier New", "monospace"]

	_slots_frutas = [slot_fruta1, slot_fruta2, slot_fruta3]
	_fruta_no_slot.resize(QTD_SLOTS)   # Array[String] -> preenchido com ""

	_registrar_opcoes()
	_conectar_sinais()
	_aplicar_estetica()

	titulo.text = TEXTO_OBJETIVO
	dica.text = TEXTO_DICA
	_sincronizar_interface()
	_mostrar_boas_vindas()


# ---------------------------------------------------------------------------
# REGISTRO DE OPÇÕES E SINAIS
# ---------------------------------------------------------------------------
func _registrar_opcoes() -> void:
	_opcoes_frutas.clear()
	_opcoes_indices.clear()

	for filho in container_frutas.get_children():
		if filho is Button:
			var id: String = str(filho.name)
			_opcoes_frutas[id] = filho
			(filho as Button).pressed.connect(_on_opcao_fruta_pressed.bind(id))

	for filho in container_indices.get_children():
		if filho is Button:
			var nome: String = str(filho.name)
			if not INDICES.has(nome):
				push_warning("Puzzle_Arrays: botão de índice '%s' não está em INDICES." % nome)
				continue
			var numero: int = INDICES[nome]
			_opcoes_indices[numero] = filho
			(filho as Button).pressed.connect(_on_opcao_indice_pressed.bind(numero))


func _conectar_sinais() -> void:
	for i in QTD_SLOTS:
		_slots_frutas[i].pressed.connect(_on_slot_fruta_pressed.bind(i))
	slot_indice.pressed.connect(_on_slot_indice_pressed)

	btn_testar.pressed.connect(_on_testar_pressed)
	btn_limpar.pressed.connect(_on_limpar_pressed)
	btn_executar.pressed.connect(_on_executar_pressed)


# ---------------------------------------------------------------------------
# SINCRONIZAÇÃO ESTADO -> INTERFACE (única função que escreve na interface)
# ---------------------------------------------------------------------------
func _sincronizar_interface() -> void:
	# Slots de frutas
	for i in QTD_SLOTS:
		var id: String = _fruta_no_slot[i]
		var slot: Button = _slots_frutas[i]
		if id == "":
			slot.text = PLACEHOLDER
			slot.tooltip_text = "Posição %d (índice %d): vazia" % [i + 1, i]
			_aplicar_estilo_slot_vazio(slot)
		else:
			slot.text = _texto_opcao(id)
			slot.tooltip_text = "Clique para retirar \"%s\" do array" % slot.text
			_aplicar_estilo_slot_preenchido(slot, COR_FRUTA)

	# Opções de frutas: desabilitadas somente se estiverem em algum slot
	for id in _opcoes_frutas:
		var botao: Button = _opcoes_frutas[id]
		var em_uso: bool = _fruta_no_slot.has(id)
		botao.disabled = em_uso
		botao.tooltip_text = "Em uso no array" if em_uso else "Clique para adicionar ao array"

	# Slot do índice
	if _indice_escolhido == -1:
		slot_indice.text = PLACEHOLDER
		slot_indice.tooltip_text = "Escolha um índice abaixo"
		_aplicar_estilo_slot_vazio(slot_indice)
	else:
		slot_indice.text = str(_indice_escolhido)
		slot_indice.tooltip_text = "Clique para limpar o índice"
		_aplicar_estilo_slot_preenchido(slot_indice, COR_INDICE)

	# Opções de índice: desabilitada somente a que está selecionada
	for numero in _opcoes_indices:
		var botao: Button = _opcoes_indices[numero]
		var selecionado: bool = numero == _indice_escolhido
		botao.disabled = selecionado
		botao.tooltip_text = "Índice em uso" if selecionado else "Clique para usar este índice"

	btn_executar.disabled = desafio_resolvido
	_atualizar_progresso()


func _texto_opcao(id: String) -> String:
	var botao: Button = _opcoes_frutas.get(id)
	return botao.text if botao != null else id


# ---------------------------------------------------------------------------
# FRUTAS: PREENCHER E REMOVER
# ---------------------------------------------------------------------------
func _on_opcao_fruta_pressed(id: String) -> void:
	if _esta_bloqueado():
		return
	if _fruta_no_slot.has(id):
		return

	var posicao: int = _fruta_no_slot.find("")
	if posicao == -1:
		_mostrar_saida(PackedStringArray([
			"[!] Todos os espaços do array já estão preenchidos.",
			"Clique em um espaço para retirar um elemento antes de escolher outro.",
		]))
		return

	_fruta_no_slot[posicao] = id
	_sincronizar_interface()
	_mostrar_saida(PackedStringArray([
		"> \"%s\" colocado na posição %d (índice %d)." % [_texto_opcao(id), posicao + 1, posicao],
	]))


func _on_slot_fruta_pressed(posicao: int) -> void:
	if _esta_bloqueado():
		return

	var id: String = _fruta_no_slot[posicao]
	if id == "":
		_mostrar_saida(PackedStringArray([
			"[!] A posição %d (índice %d) está vazia." % [posicao + 1, posicao],
			"Escolha um elemento no painel.",
		]))
		return

	var texto: String = _texto_opcao(id)
	_fruta_no_slot[posicao] = ""   # só este slot; os outros não se movem
	_sincronizar_interface()
	_mostrar_saida(PackedStringArray([
		"> \"%s\" retirado da posição %d (índice %d)." % [texto, posicao + 1, posicao],
	]))


# ---------------------------------------------------------------------------
# ÍNDICE: ESCOLHER, TROCAR E LIMPAR
# ---------------------------------------------------------------------------
func _on_opcao_indice_pressed(numero: int) -> void:
	if _esta_bloqueado():
		return
	if numero == _indice_escolhido:
		return

	_indice_escolhido = numero   # a opção anterior é liberada pela sincronização
	_sincronizar_interface()
	_mostrar_saida(PackedStringArray(["> Índice %d selecionado." % numero]))


func _on_slot_indice_pressed() -> void:
	if _esta_bloqueado():
		return
	if _indice_escolhido == -1:
		_mostrar_saida(PackedStringArray([
			"[!] O índice está vazio.",
			"Escolha 0, 1 ou 2 no painel.",
		]))
		return

	_indice_escolhido = -1
	_sincronizar_interface()
	_mostrar_saida(PackedStringArray(["> Índice removido."]))


# Depois de concluído, o array e o índice ficam travados até Limpar.
func _esta_bloqueado() -> bool:
	if desafio_resolvido:
		_mostrar_saida(PackedStringArray([
			"[OK] Desafio já concluído.",
			"[!] Clique em Limpar para recomeçar.",
		]))
		return true
	return false


# ---------------------------------------------------------------------------
# TESTAR (experimentação; NUNCA conclui o desafio)
# ---------------------------------------------------------------------------
func _on_testar_pressed() -> void:
	var linhas := PackedStringArray()
	linhas.append("> Testando consulta...")
	linhas.append("")

	if _indice_escolhido == -1:
		linhas.append("[!] Selecione um índice antes de testar.")
		_mostrar_saida(linhas)
		return

	var id: String = _consultar(_indice_escolhido)
	if id == "":
		linhas.append("[!] A posição %d (índice %d) ainda está vazia." % [_indice_escolhido + 1, _indice_escolhido])
		linhas.append("Preencha esse espaço do array para ver o resultado.")
		_mostrar_saida(linhas)
		return

	linhas.append("> console.log(%s[%d]);" % [NOME_ARRAY, _indice_escolhido])
	linhas.append("Resultado: %s" % _texto_opcao(id))
	linhas.append("")
	linhas.append("INFO: o índice %d acessa a %s posição do array." % [_indice_escolhido, ORDINAIS[_indice_escolhido]])
	_mostrar_saida(linhas)


# Node.name do elemento na posição `indice` ("" se vazia ou fora do array).
func _consultar(indice: int) -> String:
	if indice < 0 or indice >= QTD_SLOTS:
		return ""
	return _fruta_no_slot[indice]


# ---------------------------------------------------------------------------
# EXECUTAR (valida o desafio principal)
# ---------------------------------------------------------------------------
func _on_executar_pressed() -> void:
	if desafio_resolvido:
		_esta_bloqueado()
		return

	var linhas := PackedStringArray()
	linhas.append("> Executando desafio %s..." % NOME_DESAFIO)
	linhas.append("")

	match _validar_desafio():
		"incompleto":
			linhas.append("[!] Preencha todos os campos antes de executar.")
			linhas.append("[!] Campos preenchidos: %d de %d." % [_contar_preenchidos(), QTD_SLOTS + 1])
		"elemento_invalido":
			linhas.append("[X] Escolha apenas frutas para montar o array.")
			linhas.append("[X] \"%s\" não é uma fruta." % _primeiro_elemento_invalido())
		"indice_invalido":
			linhas.append("[X] Índice inválido. O array só tem as posições 0, 1 e 2.")
		"indice_errado":
			linhas.append("[X] O índice %d acessa a %s posição do array." % [_indice_escolhido, ORDINAIS[_indice_escolhido]])
			linhas.append("[X] Para acessar a segunda posição, utilize o índice correspondente.")
			linhas.append("")
			linhas.append("INFO: os índices começam em 0. Use Testar para experimentar.")
		"ok":
			_finalizar_puzzle(linhas)
			return

	_mostrar_saida(linhas)


# Devolve um código de resultado, usando SOMENTE o estado interno.
func _validar_desafio() -> String:
	# 1. Os três espaços do array e o índice precisam estar preenchidos.
	if _fruta_no_slot.has("") or _indice_escolhido == -1:
		return "incompleto"

	# 2. Todos os elementos precisam ser frutas válidas.
	for id in _fruta_no_slot:
		if not FRUTAS_VALIDAS.has(id):
			return "elemento_invalido"

	# 3. O índice precisa existir no array.
	if _indice_escolhido < 0 or _indice_escolhido >= QTD_SLOTS:
		return "indice_invalido"

	# 4. O desafio pede a segunda posição (índice 1).
	if _indice_escolhido != INDICE_ALVO:
		return "indice_errado"

	return "ok"


func _contar_preenchidos() -> int:
	var total: int = 0
	for id in _fruta_no_slot:
		if id != "":
			total += 1
	if _indice_escolhido != -1:
		total += 1
	return total


func _primeiro_elemento_invalido() -> String:
	for id in _fruta_no_slot:
		if id != "" and not FRUTAS_VALIDAS.has(id):
			return _texto_opcao(id)
	return ""


func _montar_codigo_array() -> String:
	var itens := PackedStringArray()
	for id in _fruta_no_slot:
		itens.append("\"%s\"" % _texto_opcao(id))
	return "let %s = [%s];" % [NOME_ARRAY, ", ".join(itens)]


# Conclui o desafio uma única vez (desafio_resolvido bloqueia reentrada).
func _finalizar_puzzle(linhas: PackedStringArray) -> void:
	if desafio_resolvido:
		return
	desafio_resolvido = true
	_sincronizar_interface()

	linhas.append("[OK] Correto! O índice 1 acessa a segunda posição do array.")
	linhas.append("")
	linhas.append("> " + _montar_codigo_array())
	linhas.append("> console.log(%s[%d]);" % [NOME_ARRAY, _indice_escolhido])
	linhas.append("Resultado: %s" % _texto_opcao(_consultar(_indice_escolhido)))
	linhas.append("")
	linhas.append("[OK] PUZZLE CONCLUÍDO!")
	_mostrar_saida(linhas)

	# O puzzle NÃO fecha sozinho: quem escuta o sinal (GameManager) decide o resto.
	desafio_concluido.emit()


# ---------------------------------------------------------------------------
# LIMPAR / RESET
# ---------------------------------------------------------------------------
func _on_limpar_pressed() -> void:
	resetar_puzzle()


## Restaura o estado inicial completo (lógica + interface + feedback).
## Não emite sinais.
func resetar_puzzle() -> void:
	for i in QTD_SLOTS:
		_fruta_no_slot[i] = ""
	_indice_escolhido = -1
	desafio_resolvido = false

	_sincronizar_interface()
	_mostrar_boas_vindas()


# ---------------------------------------------------------------------------
# TEXTOS
# ---------------------------------------------------------------------------
func _mostrar_boas_vindas() -> void:
	_mostrar_saida(PackedStringArray([
		"> Bem-vindo aos %s!" % NOME_FASE,
		"",
		"Monte o array e experimente diferentes índices.",
		"",
		"Clique nas opções para preencher os espaços, na ordem.",
		"Clique em um espaço preenchido para retirá-lo.",
		"Use Testar para ver o resultado e Executar para concluir.",
	]))


func _mostrar_saida(linhas: PackedStringArray) -> void:
	texto_feedback.text = "\n".join(linhas)
	texto_feedback.scroll_to_line(0)


func _atualizar_progresso() -> void:
	var preenchidos: int = QTD_SLOTS - _fruta_no_slot.count("")
	var indice_txt: String = "—" if _indice_escolhido == -1 else str(_indice_escolhido)
	indicador_desafio.text = "Progresso: %d de 1 desafio   |   Elementos no array: %d de %d   |   Índice: %s" % [
		1 if desafio_resolvido else 0, preenchidos, QTD_SLOTS, indice_txt
	]
	_estilizar_chip(chip_array)


# ---------------------------------------------------------------------------
# ESTÉTICA — APLICAÇÃO (só aparência; não mexe em lógica)
# ---------------------------------------------------------------------------
# Fundo geral preto, desenhado pelo próprio Control raiz.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)


func _aplicar_estetica() -> void:
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

	_aplicar_estilo_textos_recursivo(self)

	# Janela e painéis
	janela_puzzle.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, COR_AMARELO_MEDIO, 3, 0, -1, -1, -1, -1, 0))
	barra_titulo.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, COR_AMARELO_VIVO, 3, 12, -1, -1, 12, 6, 12))
	titulo.add_theme_color_override("font_color", COR_AMARELO_BRILHO)
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_outline_color", COR_AMARELO_FORTE)
	titulo.add_theme_constant_override("outline_size", 2)

	for painel in [painel_opcoes, painel_dica, painel_botoes]:
		painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_AMARELO_MEDIO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL))
	painel_feedback.add_theme_stylebox_override("panel", _caixa(COR_TERMINAL, COR_AMARELO_APAGADO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL, RAIO_TERMINAL))
	painel_codigo.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_AMARELO_VIVO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL, 8))

	# Cabeçalhos
	for cabecalho in [cabecalho_codigo, titulo_opcoes, titulo_indices, titulo_dica]:
		cabecalho.add_theme_color_override("font_color", COR_AMARELO_BRILHO)
		cabecalho.add_theme_font_size_override("font_size", 16)
	indicador_desafio.add_theme_font_size_override("font_size", 15)

	# Textos de leitura (RichTextLabel com rolagem própria)
	_configurar_rich_text(dica)
	_configurar_rich_text(texto_feedback)

	# Código: fonte monoespaçada em linhas fixas e slots
	_aplicar_fonte_codigo(painel_codigo)

	# Legendas dos índices (abaixo de cada slot) ficam discretas
	for no in painel_codigo.find_children("Indice*", "Label", true, false):
		var legenda := no as Label
		legenda.add_theme_color_override("font_color", COR_TEXTO_DESABILITADO)
		legenda.add_theme_font_size_override("font_size", 13)
		legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Opções (frutas e índices)
	for id in _opcoes_frutas:
		_preparar_opcao(_opcoes_frutas[id], COR_FRUTA)
	for numero in _opcoes_indices:
		_preparar_opcao(_opcoes_indices[numero], COR_INDICE)

	# Botões de ação
	_estilizar_botao_padrao(btn_testar)
	_estilizar_botao_limpar(btn_limpar)
	_estilizar_botao_executar(btn_executar)
	for botao in [btn_testar, btn_limpar, btn_executar]:
		botao.add_theme_font_size_override("font_size", TAMANHO_FONTE_BOTAO)


func _preparar_opcao(botao: Button, cor: Color) -> void:
	_estilizar_opcao(botao, cor)
	botao.add_theme_font_override("font", _fonte_mono)
	botao.add_theme_font_size_override("font_size", TAMANHO_FONTE_BOTAO)


# Texto claro e sem contorno em todos os Labels; linhas de comentário ("//")
# ficam mais discretas.
func _aplicar_estilo_textos_recursivo(no: Node) -> void:
	if no is Label:
		var rotulo := no as Label
		var cor: Color = COR_TEXTO
		if rotulo.text.strip_edges().begins_with("//"):
			cor = COR_TEXTO_DESABILITADO
		rotulo.add_theme_color_override("font_color", cor)
		rotulo.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0))
		rotulo.add_theme_constant_override("outline_size", 0)
	for filho in no.get_children():
		_aplicar_estilo_textos_recursivo(filho)


func _aplicar_fonte_codigo(no: Node) -> void:
	if (no is Label or no is Button) and no != cabecalho_codigo:
		var controle := no as Control
		controle.add_theme_font_override("font", _fonte_mono)
		controle.add_theme_font_size_override("font_size", TAMANHO_FONTE_CODIGO)
	for filho in no.get_children():
		_aplicar_fonte_codigo(filho)


func _configurar_rich_text(rich: RichTextLabel) -> void:
	rich.bbcode_enabled = false
	rich.scroll_active = true
	rich.fit_content = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_color_override("default_color", COR_TEXTO)
	rich.add_theme_font_size_override("normal_font_size", TAMANHO_FONTE_TEXTO)
	_estilizar_scrollbar(rich.get_v_scroll_bar())


func _estilizar_scrollbar(barra: VScrollBar) -> void:
	if barra == null:
		return
	barra.add_theme_stylebox_override("scroll", _caixa_simples(COR_TERMINAL))
	barra.add_theme_stylebox_override("grabber", _caixa_simples(COR_AMARELO_FORTE))
	barra.add_theme_stylebox_override("grabber_highlight", _caixa_simples(COR_AMARELO))
	barra.add_theme_stylebox_override("grabber_pressed", _caixa_simples(COR_AMARELO_VIVO))


func _caixa_simples(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(RAIO_TERMINAL)
	return sb


# ---------------------------------------------------------------------------
# BLOCOS BÁSICOS DE ESTILO
# ---------------------------------------------------------------------------
func _caixa(
		fundo: Color,
		borda: Color,
		largura: int = 2,
		brilho: int = 0,
		largura_esq: int = -1,
		largura_baixo: int = -1,
		margem_h: int = -1,
		margem_v: int = -1,
		raio: int = RAIO_BORDA
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(largura)
	if largura_esq >= 0:
		sb.border_width_left = largura_esq
	if largura_baixo >= 0:
		sb.border_width_bottom = largura_baixo
	sb.set_corner_radius_all(raio)
	if brilho > 0:
		sb.shadow_color = Color(COR_AMARELO_VIVO.r, COR_AMARELO_VIVO.g, COR_AMARELO_VIVO.b, ALFA_BRILHO)
		sb.shadow_size = brilho
		sb.shadow_offset = Vector2.ZERO
	if margem_h >= 0:
		sb.content_margin_left = margem_h
		sb.content_margin_right = margem_h
	if margem_v >= 0:
		sb.content_margin_top = margem_v
		sb.content_margin_bottom = margem_v
	return sb


func _caixa_foco(raio: int = RAIO_BORDA) -> StyleBoxFlat:
	var sb := _caixa(Color(0, 0, 0, 0), COR_AMARELO_INTENSO, 2, 0, -1, -1, -1, -1, raio)
	sb.draw_center = false
	return sb


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
	botao.add_theme_constant_override("outline_size", 0)


# ---------------------------------------------------------------------------
# BOTÕES
# ---------------------------------------------------------------------------
func _estilizar_botao_padrao(botao: Button, raio: int = RAIO_BORDA) -> void:
	var normal := _caixa(COR_BOTAO, COR_AMARELO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 2, 8, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var pressed := _caixa(COR_AMARELO_FORTE, COR_AMARELO_VIVO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var disabled := _caixa(COR_FUNDO, COR_AMARELO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(raio), disabled, COR_TEXTO)


func _estilizar_botao_executar(botao: Button) -> void:
	var normal := _caixa(COR_AMARELO_MUITO_ESCURO, COR_AMARELO_VIVO, 3, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 3, 12, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_AMARELO_FORTE, COR_AMARELO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_AMARELO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


func _estilizar_botao_limpar(botao: Button) -> void:
	var normal := _caixa(COR_AMARELO_MUITO_ESCURO, COR_AMARELO_APAGADO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_MEDIO, 2, 0, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_AMARELO_FORTE, COR_AMARELO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_AMARELO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


# ---------------------------------------------------------------------------
# OPÇÕES (borda esquerda grossa na cor da categoria)
# Disponível: borda viva. Em uso: apagada, escura e com texto discreto.
# ---------------------------------------------------------------------------
func _estilizar_opcao(botao: Button, cor: Color) -> void:
	var normal := _caixa(COR_BOTAO, cor.darkened(0.2), 2, 0, 5, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var hover := _caixa(COR_AMARELO_ESCURO, cor.lightened(0.4), 2, 8, 6, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var pressed := _caixa(COR_AMARELO_FORTE, cor, 2, 0, 5, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var disabled := _caixa(COR_FUNDO, COR_AMARELO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(RAIO_OPCAO), disabled, COR_TEXTO)


# ---------------------------------------------------------------------------
# SLOTS
# Vazio: fundo amarelo escuro, borda viva e brilho (destaca "preencha aqui").
# Preenchido: fundo preto, borda grossa na cor da categoria e texto claro.
# ---------------------------------------------------------------------------
func _aplicar_estilo_slot_vazio(slot: Button) -> void:
	var normal := _caixa(COR_AMARELO_MUITO_ESCURO, COR_AMARELO_VIVO, 2, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 2, 10, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)


func _aplicar_estilo_slot_preenchido(slot: Button, cor: Color) -> void:
	var borda: Color = COR_AMARELO_BRILHO if desafio_resolvido else cor
	var brilho: int = 8 if desafio_resolvido else 0
	var normal := _caixa(COR_FUNDO, borda, 3, brilho, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 3, 6, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_AMARELO_FORTE, COR_AMARELO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_AMARELO_BRILHO)


# ---------------------------------------------------------------------------
# CHIP DE PROGRESSO (atual / concluído)
# ---------------------------------------------------------------------------
func _estilizar_chip(chip: Label) -> void:
	var caixa: StyleBoxFlat
	var cor_texto: Color

	if desafio_resolvido:
		chip.text = "1  %s  [OK]" % NOME_DESAFIO
		caixa = _caixa(COR_AMARELO_FORTE, COR_AMARELO, 2, 0, -1, -1, 10, 3)
		cor_texto = COR_TEXTO
	else:
		chip.text = "1  %s  (atual)" % NOME_DESAFIO
		caixa = _caixa(COR_AMARELO_MUITO_ESCURO, COR_AMARELO_VIVO, 3, 10, -1, -1, 10, 3)
		cor_texto = COR_AMARELO_BRILHO

	chip.add_theme_stylebox_override("normal", caixa)
	chip.add_theme_color_override("font_color", cor_texto)


# ---------------------------------------------------------------------------
# FUNÇÕES PÚBLICAS
# (o script antigo não tinha nenhuma; estas são para consulta e reset externos)
# ---------------------------------------------------------------------------
func is_puzzle_completo() -> bool:
	return desafio_resolvido


func get_slots_frutas() -> Array[Button]:
	return _slots_frutas.duplicate()


func get_slot_indice() -> Button:
	return slot_indice


## Textos das frutas no array ("" nas posições vazias).
func get_array_montado() -> Array[String]:
	var itens: Array[String] = []
	for id in _fruta_no_slot:
		itens.append("" if id == "" else _texto_opcao(id))
	return itens


## Índice escolhido (-1 se nenhum).
func get_indice_selecionado() -> int:
	return _indice_escolhido


func get_feedback_text() -> String:
	return texto_feedback.text if texto_feedback else ""

# Obs.: não há _input() de propósito. O puzzle não fecha com ESC;
# o fechamento é feito pelo GameManager ao receber desafio_concluido.
