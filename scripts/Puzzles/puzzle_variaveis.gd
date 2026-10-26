extends Control
## Puzzle de Variáveis — Floresta Biotech (Godot 4.x | GDScript)
##
## COMO FUNCIONA
## - O jogador monta uma declaração de variável JavaScript com blocos.
##   O ";" no fim da linha já vem pronto; só os espaços (slots) são preenchidos.
## - Clicar em um bloco coloca-o no primeiro espaço livre. Clicar em um espaço
##   preenchido devolve o bloco ao painel. Blocos errados também podem ser usados
##   (são distratores educacionais).
## - Testar: valida o código e mostra o resultado, mas NUNCA conclui o puzzle.
## - Executar: valida e, se estiver correto, conclui o puzzle e emite
##   puzzle_completado + desafio_concluido (uma única vez).
## - Limpar: devolve todos os blocos ao painel e reinicia o desafio.
## - Dica: 3 níveis progressivos. Respostas erradas também liberam a próxima dica.
##
## Respostas corretas (configuráveis):  LET test = 10   |   LET test = "Test"

signal puzzle_completado()
signal puzzle_resetado()
signal desafio_concluido()

# Quando true, _validar_resposta() imprime a resposta montada no Output.
const DEBUG_VALIDACAO := false

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO DO DESAFIO
# ---------------------------------------------------------------------------
const PLACEHOLDER := "___"
const NOME_DESAFIO := "VARIÁVEIS"
const NOME_FASE := "Floresta Biotech"

const INSTRUCAO := "Puzzle de Variáveis: como é a estrutura de uma variável no JavaScript? Monte o código com os blocos."
const INFO_TITULO := "INFORMAÇÕES ÚTEIS"

const DICAS: Array[String] = [
	"Uma declaração de variável tem 3 partes: a palavra que declara junto com o nome, o sinal de atribuição e o valor.",
	"O nome de uma variável não pode começar com número, e símbolos como @ não são valores. Textos ficam entre aspas.",
	"Ordem certa: o bloco que declara a variável test, depois o sinal =, e por fim um valor (10 ou \"Test\"). O + e o ; não entram aqui.",
]

var respostas_corretas: Array = ["LET test = 10", "LET test = \"Test\""]
var ordem_original_blocos: Array = []
var desafio_resolvido: bool = false

var config_blocos: Array = [
	{"nome": "Bloco1", "tipo": "sintaxe", "texto": "LET test", "valor": "LET test"},
	{"nome": "Bloco2", "tipo": "sintaxe", "texto": "LET 1test", "valor": "LET 1test"},
	{"nome": "Bloco3", "tipo": "sintaxe", "texto": "VAR test", "valor": "VAR test"},
	{"nome": "Bloco4", "tipo": "operador", "texto": "=", "valor": "="},
	{"nome": "Bloco5", "tipo": "operador", "texto": "+", "valor": "+"},
	{"nome": "Bloco6", "tipo": "operador", "texto": ";", "valor": ";"},
	{"nome": "Bloco7", "tipo": "valor", "texto": "10", "valor": "10"},
	{"nome": "Bloco8", "tipo": "valor", "texto": "\"Test\"", "valor": "\"Test\""},
	{"nome": "Bloco9", "tipo": "valor", "texto": "@", "valor": "@"}
]

# Mensagem específica para cada bloco errado (explica o PORQUÊ).
var dicas_por_valor: Dictionary = {
	"LET 1test": "Um nome de variável não pode começar com número.",
	"VAR test": "Neste desafio, a declaração esperada é a que usa LET.",
	"@": "O símbolo @ não é um valor válido em JavaScript.",
	"+": "O operador + soma valores. Para guardar um valor, use o operador de atribuição (=).",
	";": "O ponto e vírgula já está pronto no fim da linha.",
}

# ---------------------------------------------------------------------------
# ESTÉTICA — PALETA (PRETO + AMARELO FLORESTA BIOTECH + BRANCO)
# Mesma estrutura de tons dos outros puzzles, trocando o matiz para amarelo.
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

# Categorias de bloco (todas na família amarela).
const CORES_TIPO := {
	"sintaxe": Color("e6d84f"),
	"operador": Color("ffb938"),
	"valor": Color("b4e65a"),
}
const COR_TIPO_PADRAO := Color("e6d84f")

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
@onready var chip_variaveis: Label = %ChipVariaveis

@onready var painel_informacoes: PanelContainer = %PainelInformacoes
@onready var titulo_informacoes: Label = %TituloInformacoes
@onready var texto_informacoes: RichTextLabel = %TextoInformacoes

@onready var painel_codigo: PanelContainer = %PainelCodigo
@onready var cabecalho_codigo: Label = %CabecalhoCodigo
@onready var slots_container: Container = %LinhaCodigo

@onready var painel_opcoes: PanelContainer = %PainelOpcoes
@onready var titulo_opcoes: Label = %TituloOpcoes
@onready var legenda_blocos: Label = %LegendaBlocos
@onready var blocos_container: Container = %AreaBlocos

@onready var painel_feedback: PanelContainer = %PainelFeedback
@onready var texto_feedback: RichTextLabel = %TextoFeedback

@onready var painel_botoes: PanelContainer = %PainelBotoes
@onready var btn_dica: Button = %Dica
@onready var btn_testar: Button = %Testar
@onready var botao_limpar: Button = %Limpar
@onready var botao_executar: Button = %Executar

# ---------------------------------------------------------------------------
# ESTADO
# ---------------------------------------------------------------------------
var _slots: Array[Button] = []
var _bloco_do_slot: Array = []   # um item por slot: Button ou null
var _nivel_dica: int = 0
var _fonte_mono: SystemFont


func _ready() -> void:
	_fonte_mono = SystemFont.new()
	_fonte_mono.font_names = ["Consolas", "Courier New", "monospace"]

	_coletar_slots()
	_configurar_blocos()
	_conectar_botoes()

	_aplicar_estetica()
	_atualizar_slots_visual()
	_atualizar_progresso()

	texto_informacoes.text = _montar_texto_informacoes()
	texto_informacoes.scroll_to_line(0)
	titulo.text = INSTRUCAO
	titulo_informacoes.text = INFO_TITULO

	_mostrar_saida(PackedStringArray([
		"> Bem-vindo à %s!" % NOME_FASE,
		"",
		"Clique nos blocos para preencher os espaços brilhantes do código.",
		"Clique em um espaço preenchido para retirar o bloco.",
		"Use Testar para verificar e Dica se precisar de ajuda.",
	]))


# ---------------------------------------------------------------------------
# CONFIGURAÇÃO DE SLOTS, BLOCOS E BOTÕES
# ---------------------------------------------------------------------------
func _coletar_slots() -> void:
	_slots.clear()
	_bloco_do_slot.clear()
	if not slots_container:
		return

	for filho in slots_container.get_children():
		if filho is Button:
			_slots.append(filho as Button)

	_bloco_do_slot.resize(_slots.size())  # preenche com null

	for i in _slots.size():
		var slot: Button = _slots[i]
		slot.text = PLACEHOLDER
		slot.pressed.connect(_on_slot_pressionado.bind(i))


# Os blocos Bloco1..Bloco9 já existem na cena; o script só os configura a partir
# de config_blocos. Blocos que faltam na cena são criados; os que sobram, removidos.
func _configurar_blocos() -> void:
	if not blocos_container:
		return

	ordem_original_blocos.clear()

	var nomes_config: Array[String] = []
	for config in config_blocos:
		nomes_config.append(str(config.get("nome", "")))

	for filho in blocos_container.get_children():
		if not nomes_config.has(str(filho.name)):
			blocos_container.remove_child(filho)
			filho.queue_free()

	for i in config_blocos.size():
		var config: Dictionary = config_blocos[i]
		var nome: String = str(config.get("nome", "Bloco%d" % (i + 1)))
		var bloco: Button = _encontrar_bloco_por_nome(nome)
		if bloco == null:
			bloco = Button.new()
			bloco.name = nome
			blocos_container.add_child(bloco)

		_configurar_bloco(bloco, config)
		blocos_container.move_child(bloco, i)
		ordem_original_blocos.append({"bloco": bloco, "indice": i})


func _encontrar_bloco_por_nome(nome: String) -> Button:
	for filho in blocos_container.get_children():
		if str(filho.name) == nome:
			return filho as Button
	return null


func _configurar_bloco(bloco: Button, config: Dictionary) -> void:
	var texto: String = str(config.get("texto", config.get("valor", "")))
	var valor: String = str(config.get("valor", texto))
	var tipo: String = str(config.get("tipo", "sintaxe"))

	bloco.text = texto
	bloco.visible = true
	bloco.disabled = false
	bloco.custom_minimum_size = Vector2(0, 38)
	bloco.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bloco.set_meta("valor", valor)
	bloco.set_meta("texto", texto)
	bloco.set_meta("tipo", tipo)

	_estilizar_bloco(bloco, tipo)

	if not bloco.get_meta("conectado", false):
		bloco.pressed.connect(_on_bloco_clicado.bind(bloco))
		bloco.set_meta("conectado", true)


# Cada conexão é protegida por is_connected para evitar duplicidade caso o
# sinal já tenha sido ligado pelo editor.
func _conectar_botoes() -> void:
	if not botao_executar.pressed.is_connected(_on_executar_pressed):
		botao_executar.pressed.connect(_on_executar_pressed)
	if not botao_limpar.pressed.is_connected(_on_limpar_pressed):
		botao_limpar.pressed.connect(_on_limpar_pressed)
	if not btn_testar.pressed.is_connected(_on_testar_pressed):
		btn_testar.pressed.connect(_on_testar_pressed)
	if not btn_dica.pressed.is_connected(_on_dica_pressed):
		btn_dica.pressed.connect(_on_dica_pressed)


# ---------------------------------------------------------------------------
# COLOCAR / REMOVER BLOCOS
# ---------------------------------------------------------------------------
func _on_bloco_clicado(bloco: Node) -> void:
	if not is_instance_valid(bloco):
		return

	if desafio_resolvido:
		_mostrar_saida(PackedStringArray([
			"[!] Puzzle já foi resolvido!",
			"Clique em Limpar para recomeçar.",
		]))
		return

	if _bloco_esta_em_slot(bloco):
		return

	var indice: int = _procurar_primeiro_slot_vazio()
	if indice == -1:
		_mostrar_saida(PackedStringArray([
			"[!] Todos os espaços já estão preenchidos.",
			"Clique em um espaço para retirar o bloco antes de escolher outro.",
		]))
		return

	_colocar_bloco_no_slot(indice, bloco)

	if _todos_slots_preenchidos():
		_mostrar_saida(PackedStringArray([
			"[OK] Todos os espaços preenchidos.",
			"Clique em Testar para verificar ou em Executar para concluir.",
		]))
	else:
		_mostrar_saida(PackedStringArray([
			"> Bloco \"%s\" colocado no espaço %d." % [_obter_texto_bloco(bloco), indice + 1],
		]))


func _on_slot_pressionado(indice: int) -> void:
	if desafio_resolvido:
		_mostrar_saida(PackedStringArray([
			"[!] Puzzle já foi resolvido!",
			"Clique em Limpar para recomeçar.",
		]))
		return

	var bloco = _bloco_do_slot[indice]
	if bloco == null or not is_instance_valid(bloco):
		_mostrar_saida(PackedStringArray([
			"[!] O espaço %d está vazio." % (indice + 1),
			"Escolha um bloco no painel.",
		]))
		return

	var texto: String = _obter_texto_bloco(bloco)
	_remover_bloco_do_slot(indice)
	_mostrar_saida(PackedStringArray([
		"> Bloco \"%s\" devolvido ao painel." % texto,
	]))


func _bloco_esta_em_slot(bloco: Node) -> bool:
	return _bloco_do_slot.has(bloco)


func _procurar_primeiro_slot_vazio() -> int:
	for i in _bloco_do_slot.size():
		if _bloco_do_slot[i] == null:
			return i
	return -1


func _todos_slots_preenchidos() -> bool:
	return not _slots.is_empty() and _procurar_primeiro_slot_vazio() == -1


func _contar_slots_preenchidos() -> int:
	var total: int = 0
	for bloco in _bloco_do_slot:
		if bloco != null:
			total += 1
	return total


func _colocar_bloco_no_slot(indice: int, bloco: Node) -> void:
	_bloco_do_slot[indice] = bloco
	if bloco is Button:
		var botao := bloco as Button
		botao.visible = false
		botao.disabled = true
	_atualizar_slot_visual(indice)
	_atualizar_progresso()


func _remover_bloco_do_slot(indice: int) -> void:
	var bloco = _bloco_do_slot[indice]
	_bloco_do_slot[indice] = null
	if bloco != null and is_instance_valid(bloco) and bloco is Button:
		var botao := bloco as Button
		botao.visible = true
		botao.disabled = false
	_atualizar_slot_visual(indice)
	_atualizar_progresso()


# ---------------------------------------------------------------------------
# MONTAGEM E VALIDAÇÃO
# ---------------------------------------------------------------------------
func _obter_valor_bloco(bloco: Node) -> String:
	if bloco.has_meta("valor"):
		return str(bloco.get_meta("valor"))
	if bloco.has_method("get_valor"):
		return bloco.get_valor()
	if bloco.has_method("get_texto"):
		return bloco.get_texto()
	for child in bloco.get_children():
		if child is Label:
			return child.text
	return str(bloco.name)


func _obter_texto_bloco(bloco: Node) -> String:
	if bloco.has_meta("texto"):
		return str(bloco.get_meta("texto"))
	if bloco is Button:
		return (bloco as Button).text
	return _obter_valor_bloco(bloco)


func _valores_dos_slots() -> PackedStringArray:
	var valores := PackedStringArray()
	for bloco in _bloco_do_slot:
		if bloco != null and is_instance_valid(bloco):
			valores.append(_obter_valor_bloco(bloco))
		else:
			valores.append("[vazio]")
	return valores


func _montar_resposta() -> String:
	return " ".join(_valores_dos_slots())


func _normalizar_string(texto: String) -> String:
	var normalizado: String = texto.replace("“", "\"").replace("”", "\"").replace("'", "\"")
	normalizado = normalizado.strip_edges()
	return " ".join(normalizado.split(" ", false))  # colapsa espaços repetidos


func _validar_resposta() -> bool:
	if not _todos_slots_preenchidos():
		return false

	var resposta: String = _normalizar_string(_montar_resposta())
	if DEBUG_VALIDACAO:
		print("[Puzzle_Variaveis] resposta montada: '%s'" % resposta)

	for resposta_correta in respostas_corretas:
		if resposta == _normalizar_string(str(resposta_correta)):
			return true
	return false


# ---------------------------------------------------------------------------
# DICAS
# ---------------------------------------------------------------------------
func _proxima_dica() -> PackedStringArray:
	_nivel_dica = mini(_nivel_dica + 1, DICAS.size())
	return PackedStringArray(["DICA %d/%d:" % [_nivel_dica, DICAS.size()], DICAS[_nivel_dica - 1]])


func _on_dica_pressed() -> void:
	var linhas := PackedStringArray()
	linhas.append("> Pedindo uma dica para o desafio %s..." % NOME_DESAFIO)
	linhas.append("")
	if desafio_resolvido:
		linhas.append("[OK] Este desafio já foi concluído.")
	else:
		linhas.append_array(_proxima_dica())
	_mostrar_saida(linhas)


# ---------------------------------------------------------------------------
# TESTAR E EXECUTAR
# ---------------------------------------------------------------------------
func _on_testar_pressed() -> void:
	_verificar(false)


func _on_executar_pressed() -> void:
	_verificar(true)


func _verificar(modo_executar: bool) -> void:
	var linhas := PackedStringArray()
	linhas.append("> %s desafio %s..." % ["Executando" if modo_executar else "Testando", NOME_DESAFIO])
	linhas.append("")

	if desafio_resolvido:
		linhas.append("[OK] Este desafio já foi concluído.")
		linhas.append("[!] Clique em Limpar para recomeçar.")
		_mostrar_saida(linhas)
		return

	if not _todos_slots_preenchidos():
		linhas.append("[!] Existem espaços vazios.")
		linhas.append("[!] Preencha todos os espaços (%d de %d)." % [_contar_slots_preenchidos(), _slots.size()])
		_mostrar_saida(linhas)
		return

	if not _validar_resposta():
		_adicionar_feedback_erro(linhas)
		_mostrar_saida(linhas)
		return

	if modo_executar:
		_finalizar_puzzle(linhas)
	else:
		linhas.append("[OK] Código correto!")
		linhas.append("> %s;" % _montar_resposta())
		linhas.append("")
		linhas.append("INFO: clique em Executar para confirmar a finalização do puzzle.")
		_mostrar_saida(linhas)


func _adicionar_feedback_erro(linhas: PackedStringArray) -> void:
	linhas.append("[X] O código ainda não está correto.")
	linhas.append("")

	var vistos := PackedStringArray()
	for valor in _valores_dos_slots():
		if dicas_por_valor.has(valor) and not vistos.has(valor):
			vistos.append(valor)
			linhas.append("[X] " + str(dicas_por_valor[valor]))

	if vistos.is_empty():
		linhas.append("[X] Revise a ordem: declaração, operador de atribuição e valor.")

	linhas.append("")
	linhas.append_array(_proxima_dica())


# Conclui o puzzle uma única vez.
func _finalizar_puzzle(linhas: PackedStringArray) -> void:
	desafio_resolvido = true
	botao_executar.disabled = true
	_atualizar_slots_visual()
	_atualizar_progresso()

	linhas.append("[OK] Variável criada com sucesso!")
	linhas.append("> %s;" % _montar_resposta())
	linhas.append("")
	linhas.append("[OK] PUZZLE CONCLUÍDO!")
	linhas.append("INFO: você aprendeu a declarar uma variável.")
	_mostrar_saida(linhas)

	# O puzzle NÃO fecha sozinho: quem escuta os sinais (GameManager) decide o resto.
	puzzle_completado.emit()
	desafio_concluido.emit()


# ---------------------------------------------------------------------------
# LIMPAR
# ---------------------------------------------------------------------------
func _on_limpar_pressed() -> void:
	_limpar_puzzle()
	_mostrar_saida(PackedStringArray([
		"> Limpando desafio %s..." % NOME_DESAFIO,
		"",
		"[OK] Desafio limpo.",
		"[INFO] Os blocos foram devolvidos ao painel.",
	]))


func _limpar_puzzle() -> void:
	for i in _bloco_do_slot.size():
		_bloco_do_slot[i] = null

	if blocos_container:
		for bloco in blocos_container.get_children():
			if bloco is Button:
				var botao := bloco as Button
				botao.visible = true
				botao.disabled = false

	_restaurar_ordem_blocos()

	desafio_resolvido = false
	botao_executar.disabled = false

	_atualizar_slots_visual()
	_atualizar_progresso()
	puzzle_resetado.emit()


func _restaurar_ordem_blocos() -> void:
	if not blocos_container:
		return
	for item in ordem_original_blocos:
		var bloco: Node = item["bloco"]
		if not is_instance_valid(bloco):
			continue
		var pai: Node = bloco.get_parent()
		if pai != blocos_container:
			if pai:
				pai.remove_child(bloco)
			blocos_container.add_child(bloco)
		blocos_container.move_child(bloco, mini(int(item["indice"]), blocos_container.get_child_count() - 1))


# ---------------------------------------------------------------------------
# TEXTOS
# ---------------------------------------------------------------------------
func _mostrar_saida(linhas: PackedStringArray) -> void:
	texto_feedback.text = "\n".join(linhas)
	texto_feedback.scroll_to_line(0)


func _montar_texto_informacoes() -> String:
	var linhas := PackedStringArray()
	linhas.append("Uma variável é um espaço com nome, usado para guardar um valor.")
	linhas.append("")
	linhas.append("Estrutura:")
	linhas.append("declaração nome = valor;")
	linhas.append("")
	linhas.append("• declaração: a palavra que cria a variável junto com o nome.")
	linhas.append("• nome: não pode começar com número nem usar símbolos como @.")
	linhas.append("• =: guarda o valor dentro da variável.")
	linhas.append("• valor: um número (10) ou um texto entre aspas (\"Test\").")
	linhas.append("")
	linhas.append("O ; que termina a linha já está pronto.")
	linhas.append("")
	linhas.append("Objetivo: montar a declaração de uma variável chamada test.")
	linhas.append("")
	linhas.append("Preencha os %d espaços brilhantes. Travou? Clique em Dica." % maxi(_slots.size(), 3))
	return "\n".join(linhas)


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

	for painel in [painel_informacoes, painel_opcoes, painel_botoes]:
		painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_AMARELO_MEDIO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL))
	painel_feedback.add_theme_stylebox_override("panel", _caixa(COR_TERMINAL, COR_AMARELO_APAGADO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL, RAIO_TERMINAL))

	# Painel de código (destacado)
	painel_codigo.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_AMARELO_VIVO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL, 8))

	# Cabeçalhos
	for cabecalho in [cabecalho_codigo, titulo_informacoes, titulo_opcoes]:
		cabecalho.add_theme_color_override("font_color", COR_AMARELO_BRILHO)
		cabecalho.add_theme_font_size_override("font_size", 16)
	indicador_desafio.add_theme_font_size_override("font_size", 15)
	legenda_blocos.add_theme_color_override("font_color", COR_TEXTO_DESABILITADO)
	legenda_blocos.add_theme_font_size_override("font_size", 13)

	# Textos de leitura (RichTextLabel com rolagem própria)
	_configurar_rich_text(texto_informacoes)
	_configurar_rich_text(texto_feedback)

	# Código: fonte monoespaçada em linhas fixas e slots
	_aplicar_fonte_codigo(painel_codigo)

	# Fonte dos blocos de opção
	for filho in blocos_container.get_children():
		if filho is Button:
			var botao := filho as Button
			botao.add_theme_font_override("font", _fonte_mono)
			botao.add_theme_font_size_override("font_size", TAMANHO_FONTE_BOTAO)

	# Botões de ação
	_estilizar_botao_padrao(btn_testar)
	_estilizar_botao_padrao(btn_dica)
	_estilizar_botao_executar(botao_executar)
	_estilizar_botao_limpar(botao_limpar)
	for botao in [btn_testar, btn_dica, botao_executar, botao_limpar]:
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
# BLOCOS DE OPÇÃO (a borda esquerda grossa na cor da categoria)
# ---------------------------------------------------------------------------
func _estilizar_bloco(botao: Button, tipo: String) -> void:
	var cor: Color = CORES_TIPO.get(tipo, COR_TIPO_PADRAO)
	var normal := _caixa(COR_BOTAO, cor.darkened(0.2), 2, 0, 5, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var hover := _caixa(COR_AMARELO_ESCURO, cor.lightened(0.4), 2, 8, 6, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var pressed := _caixa(COR_AMARELO_FORTE, cor, 2, 0, 5, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	var disabled := _caixa(COR_FUNDO, COR_AMARELO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, RAIO_OPCAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(RAIO_OPCAO), disabled, COR_TEXTO)


# ---------------------------------------------------------------------------
# SLOTS
# Vazio: fundo amarelo escuro, borda viva e brilho (destaca "preencha aqui").
# Preenchido: fundo preto, borda na cor da categoria e texto claro.
# ---------------------------------------------------------------------------
func _atualizar_slots_visual() -> void:
	for i in _slots.size():
		_atualizar_slot_visual(i)


func _atualizar_slot_visual(indice: int) -> void:
	var slot: Button = _slots[indice]
	var bloco = _bloco_do_slot[indice]

	if bloco == null or not is_instance_valid(bloco):
		slot.text = PLACEHOLDER
		slot.tooltip_text = "Espaço %d (livre)" % (indice + 1)
		_aplicar_estilo_slot_vazio(slot)
	else:
		slot.text = _obter_texto_bloco(bloco)
		slot.tooltip_text = "Clique para devolver o bloco ao painel"
		var tipo: String = str(bloco.get_meta("tipo", "sintaxe"))
		_aplicar_estilo_slot_preenchido(slot, tipo)


func _aplicar_estilo_slot_vazio(slot: Button) -> void:
	var normal := _caixa(COR_AMARELO_MUITO_ESCURO, COR_AMARELO_VIVO, 2, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 2, 10, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)


func _aplicar_estilo_slot_preenchido(slot: Button, tipo: String) -> void:
	var cor: Color = CORES_TIPO.get(tipo, COR_TIPO_PADRAO)
	var brilho: int = 8 if desafio_resolvido else 0
	var borda: Color = COR_AMARELO_BRILHO if desafio_resolvido else cor
	var normal := _caixa(COR_FUNDO, borda, 3, brilho, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_AMARELO_ESCURO, COR_AMARELO_BRILHO, 3, 6, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_AMARELO_FORTE, COR_AMARELO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_AMARELO_BRILHO)


# ---------------------------------------------------------------------------
# PROGRESSO / CHIP
# ---------------------------------------------------------------------------
func _atualizar_progresso() -> void:
	var concluidos: int = 1 if desafio_resolvido else 0
	indicador_desafio.text = "Progresso: %d de 1 desafio   |   Blocos no código: %d de %d   |   %s" % [
		concluidos, _contar_slots_preenchidos(), _slots.size(), NOME_FASE
	]
	_estilizar_chip(chip_variaveis)


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
# FUNÇÕES PÚBLICAS (compatíveis com o puzzle original)
# ---------------------------------------------------------------------------
func definir_resposta_correta(resposta: String) -> void:
	respostas_corretas = [resposta]


func definir_respostas_corretas(novas_respostas: Array) -> void:
	respostas_corretas = novas_respostas


func configurar_novo_desafio(nova_config_blocos: Array, nova_resposta) -> void:
	if not is_node_ready():
		await ready

	if typeof(nova_resposta) == TYPE_STRING:
		respostas_corretas = [nova_resposta]
	elif typeof(nova_resposta) == TYPE_ARRAY:
		respostas_corretas = nova_resposta

	config_blocos = nova_config_blocos
	_nivel_dica = 0

	_limpar_puzzle()
	_configurar_blocos()
	_aplicar_fonte_blocos()
	_atualizar_slots_visual()
	_atualizar_progresso()
	_mostrar_saida(PackedStringArray(["[INFO] Novo desafio carregado!"]))


func _aplicar_fonte_blocos() -> void:
	for filho in blocos_container.get_children():
		if filho is Button:
			var botao := filho as Button
			botao.add_theme_font_override("font", _fonte_mono)
			botao.add_theme_font_size_override("font_size", TAMANHO_FONTE_BOTAO)


func get_slots() -> Array:
	return _slots.duplicate()


func get_blocos() -> Array:
	var blocos := []
	if blocos_container:
		for bloco in blocos_container.get_children():
			blocos.append(bloco)
	return blocos


func get_resposta_jogador() -> String:
	return _montar_resposta()


func is_puzzle_completo() -> bool:
	return desafio_resolvido


func get_feedback_text() -> String:
	return texto_feedback.text if texto_feedback else ""


func get_respostas_corretas() -> Array:
	return respostas_corretas


func resetar_puzzle() -> void:
	_limpar_puzzle()
	_mostrar_saida(PackedStringArray(["> Puzzle reiniciado."]))

# Obs.: não há _input() de propósito. O puzzle não fecha com ESC;
# o fechamento é feito pelo GameManager ao receber desafio_concluido.
