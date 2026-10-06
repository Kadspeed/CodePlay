extends Control

## Puzzle_cidade — Puzzle de FUNÇÕES do CodePlay.
## O jogador monta a sequência correta de código clicando em opções,
## que são colocadas nos slots na ordem em que forem clicadas.
## Não executa JavaScript de verdade: apenas compara a sequência de
## textos escolhida com a resposta correta.


# --- Configuração do puzzle -------------------------------------------------

## Sequência correta que os 3 slots devem formar, nesta ordem exata.
const RESPOSTA_CORRETA: Array[String] = [
	"function",
	"saudar()",
	"console.log(\"Olá!\")"
]

## Mapeia o nome de cada botão de PainelOpcoes para o texto de código
## que ele representa. As chaves são exatamente os nomes dos nós na cena.
const OPCOES: Dictionary = {
	"Function": "function",
	"Saudar()": "saudar()",
	"Console_log(_ola_)": "console.log(\"Olá!\")",
	"Return": "return",
	"For": "for",
	"IF": "if"
}

## Textos de feedback usados nas diferentes situações.
const FEEDBACK_INICIAL := "Monte o código para criar uma função."
const FEEDBACK_INCOMPLETO := "Código incompleto! Preencha todos os espaços."
const FEEDBACK_INCORRETO := "Código incorreto! Verifique a ordem das opções."
const FEEDBACK_CORRETO := "Correto! Você criou uma função que exibe uma mensagem no console."

## Conteúdo do painel de Objetivo: o objetivo é a informação principal e
## as curiosidades são complementares.
const TEXTO_OBJETIVO := "Monte uma função que mostre a mensagem \"Olá!\" no console."
const TITULO_CURIOSIDADES := "CURIOSIDADES"
const CURIOSIDADES: Array[String] = [
	"Funções permitem organizar um conjunto de instruções que pode ser reutilizado.",
	"Uma função pode ser chamada várias vezes ao longo do programa.",
	"Funções podem receber informações chamadas parâmetros.",
	"Uma função também pode devolver um valor usando \"return\"."
]


# --- Paleta visual (PRETO + AZUL-CLARO + BRANCO) -----------------------------

const COR_FUNDO := Color("000000")
const COR_PAINEL := Color("03050a")
const COR_BOTAO := Color("07090f")
const COR_AZUL := Color("4fc3f7")            # azul-claro principal (bordas)
const COR_AZUL_BRILHO := Color("b8efff")     # azul-claro mais brilhante (hover/focus)
const COR_AZUL_APAGADO := Color("2a7fa6")    # azul-claro mais discreto (slot vazio, desabilitado)
const COR_AZUL_ESCURO := Color("051c2b")     # tom escuro para o hover parcial
const COR_AZUL_FORTE := Color("0a4f8a")      # azul mais forte/escuro (pressed)
const COR_TEXTO := Color("f2f8ff")
const COR_TEXTO_DESABILITADO := Color("5f8296")

const RAIO_BORDA := 6


# --- Sinais ------------------------------------------------------------------

## Emitido quando o puzzle é resolvido corretamente, seguindo o mesmo padrão
## usado pelos outros puzzles do projeto (ex.: Puzzle_Loops) para avisar
## o PC / GameManager que a fase pode progredir.
signal desafio_concluido


# --- Estado interno ------------------------------------------------------------

## Para cada slot (índice 0, 1, 2), guarda a CHAVE da opção que está nele
## (ex.: "Function"), ou "" se o slot estiver vazio.
## É esse array que permite remover um slot do meio sem reorganizar os outros.
var slot_conteudo: Array[String] = ["", "", ""]

## Evita emitir puzzle_concluido mais de uma vez caso o jogador clique
## em Executar novamente depois de já ter acertado.
var puzzle_ja_concluido := false


# --- Referências aos nós ------------------------------------------------------

@onready var feedback_label: Label = $PainelFeedback/Feedback

@onready var slots: Array[Button] = [
	$PainelCodigo/Slot1,
	$PainelCodigo/Slot2,
	$PainelCodigo/Slot3
]

## Botões de opção. Usamos get_node() (em vez de $) porque alguns nomes
## têm parênteses, o que causaria problemas com a sintaxe $NomeDoNo.
@onready var botoes_opcoes: Dictionary = {}

@onready var botao_executar: Button = $BotaoExecutar

## Texto do painel de Objetivo (pode ser Label ou RichTextLabel).
@onready var texto_objetivo: Control = get_node_or_null("PainelObjetivo/TextoObjetivo")

## Usado para comparar nomes de nós "ignorando" maiúsculas, acentos e
## caracteres especiais, caso o nome real do botão no editor seja
## levemente diferente do nome esperado em OPCOES.
static var _regex_normalizacao: RegEx = RegEx.create_from_string("[^a-z0-9]")


func _ready() -> void:
	_carregar_botoes_opcoes()
	_conectar_sinais()
	_aplicar_estetica()
	_configurar_painel_objetivo()
	feedback_label.text = FEEDBACK_INICIAL


## Fundo geral preto. Desenhado pelo próprio Control raiz (fica atrás dos filhos),
## então não precisa de nenhum nó novo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)


## Busca cada botão de PainelOpcoes pelo nome do nó e guarda a referência
## no dicionário botoes_opcoes, usando a mesma chave de OPCOES.
## Se o nome exato não existir, tenta achar por comparação normalizada
## (evita quebrar o jogo por causa de uma pequena diferença de nome).
func _carregar_botoes_opcoes() -> void:
	var painel_opcoes := get_node("PainelOpcoes")

	for nome_opcao in OPCOES.keys():
		var botao: Node = painel_opcoes.get_node_or_null(nome_opcao)

		if botao == null:
			botao = _buscar_botao_por_nome_flexivel(painel_opcoes, nome_opcao)

		if botao == null or not (botao is Button):
			push_error(
				("Puzzle_cidade: não encontrei o botão da opção '%s' dentro de PainelOpcoes. "
				+ "Confira o nome exato desse nó no editor e ajuste OPCOES no script se necessário.")
				% nome_opcao
			)
			continue

		botoes_opcoes[nome_opcao] = botao


## Procura, entre os filhos de painel_opcoes, um Button cujo nome
## normalizado (minúsculo, sem acento/pontuação) bata com nome_esperado.
func _buscar_botao_por_nome_flexivel(painel_opcoes: Node, nome_esperado: String) -> Button:
	var alvo := _normalizar_nome(nome_esperado)
	for filho in painel_opcoes.get_children():
		if filho is Button and _normalizar_nome(filho.name) == alvo:
			return filho
	return null


func _normalizar_nome(nome: String) -> String:
	return _regex_normalizacao.sub(nome.to_lower(), "", true)


func _conectar_sinais() -> void:
	# Um clique em cada opção chama _on_opcao_pressionada com o nome dela.
	for nome_opcao in botoes_opcoes.keys():
		var botao: Button = botoes_opcoes[nome_opcao]
		botao.pressed.connect(_on_opcao_pressionada.bind(nome_opcao))

	# Um clique em cada slot chama _on_slot_pressionado com o índice dele.
	for indice in range(slots.size()):
		slots[indice].pressed.connect(_on_slot_pressionado.bind(indice))

	botao_executar.pressed.connect(_on_botao_executar_pressed)


# --- Estética (tudo por StyleBoxFlat + theme overrides) ------------------------

## Aplica a identidade visual inteira. Não mexe em posição, tamanho ou estrutura.
func _aplicar_estetica() -> void:
	# Redesenha o fundo preto quando a cena for redimensionada.
	resized.connect(queue_redraw)
	queue_redraw()

	# Texto principal branco em todos os Labels da cena.
	for no in find_children("*", "Label", true, false):
		no.add_theme_color_override("font_color", COR_TEXTO)

	# Painéis: fundo preto, borda azul-claro arredondada, leve brilho.
	for nome in ["PainelCodigo", "PainelObjetivo", "PainelOpcoes", "PainelFeedback"]:
		var painel := get_node_or_null(nome) as Control
		if painel != null:
			painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_AZUL, 2, 6))

	# Títulos (Labels ou áreas delimitadas de título).
	_estilizar_titulo("Titulo", true)
	_estilizar_titulo("PainelCodigo/TituloArea")
	_estilizar_titulo("PainelObjetivo/TituloArea")
	_estilizar_titulo("PainelOpcoes/TituloArea")
	_estilizar_titulo("PainelFeedback/TituloFeedback")

	# Botões de opção.
	for nome_opcao in botoes_opcoes.keys():
		_estilizar_botao_padrao(botoes_opcoes[nome_opcao])

	# Botão Executar.
	_estilizar_botao_padrao(botao_executar)

	# Slots (aparência depende de estarem vazios ou preenchidos).
	for indice in range(slots.size()):
		_atualizar_estilo_slot(indice)


## Cria um StyleBoxFlat.
## - largura: espessura da borda em todos os lados;
## - brilho: tamanho da sombra azul (efeito de luz); 0 = sem brilho;
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
		sb.shadow_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.35)
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
	var sb := _caixa(Color(0, 0, 0, 0), COR_AZUL_BRILHO, 2)
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


## Botões de opção e BotaoExecutar.
## Hover PARCIAL: o botão continua escuro, mas ganha borda mais brilhante,
## faixa mais grossa à esquerda e embaixo e um tom azul bem escuro no fundo.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_AZUL, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_AZUL_ESCURO, COR_AZUL_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_AZUL_FORTE, COR_AZUL, 2, 0, -1, -1, 10, 6)
	var disabled := _caixa(COR_FUNDO, COR_AZUL_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


## Título: fundo preto, borda azul-claro arredondada, texto branco.
## O título principal ("FUNÇÕES") ganha borda mais grossa/brilhante, brilho e texto azul-claro.
## Funciona se o nó for um Label ou uma área (Panel/PanelContainer) com Label dentro.
func _estilizar_titulo(caminho: NodePath, destaque: bool = false) -> void:
	var no := get_node_or_null(caminho) as Control
	if no == null:
		return

	var borda := COR_AZUL_BRILHO if destaque else COR_AZUL
	var largura := 3 if destaque else 2
	var brilho := 12 if destaque else 0
	var caixa := _caixa(COR_FUNDO, borda, largura, brilho, -1, -1, 10, 2)
	var cor_texto := COR_AZUL_BRILHO if destaque else COR_TEXTO

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
		label.add_theme_color_override("font_outline_color", COR_AZUL_FORTE)
		label.add_theme_constant_override("outline_size", 3)


## Slot vazio: preto, borda azul-claro fina/discreta.
## Slot preenchido: preto, borda azul-claro grossa com brilho e texto em azul-claro.
## O hover do slot preenchido usa o mesmo destaque parcial dos botões.
func _atualizar_estilo_slot(indice: int) -> void:
	var slot := slots[indice]

	if slot_conteudo[indice] == "":
		var normal := _caixa(COR_FUNDO, COR_AZUL_APAGADO, 1, 0, -1, -1, 10, 6)
		var hover := _caixa(COR_FUNDO, COR_AZUL, 2, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)
	else:
		var normal := _caixa(COR_FUNDO, COR_AZUL, 3, 8, -1, -1, 10, 6)
		var hover := _caixa(COR_AZUL_ESCURO, COR_AZUL_BRILHO, 3, 10, 7, 6, 10, 6)
		var pressed := _caixa(COR_AZUL_FORTE, COR_AZUL, 3, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_AZUL_BRILHO)


# --- Painel de Objetivo --------------------------------------------------------

## Preenche o TextoObjetivo com o objetivo + a seção CURIOSIDADES.
## - RichTextLabel: usa BBCode (título da seção em azul-claro e negrito) e
##   deixa a rolagem ativa caso o texto não caiba no tamanho atual do nó.
## - Label: usa texto simples com quebra de linha automática.
func _configurar_painel_objetivo() -> void:
	if texto_objetivo == null:
		push_error("Puzzle_cidade: não encontrei PainelObjetivo/TextoObjetivo.")
		return

	if texto_objetivo is RichTextLabel:
		var rich := texto_objetivo as RichTextLabel
		rich.bbcode_enabled = true
		rich.scroll_active = true
		rich.add_theme_color_override("default_color", COR_TEXTO)
		rich.text = _montar_texto_objetivo(true)
	elif texto_objetivo is Label:
		var label := texto_objetivo as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _montar_texto_objetivo(false)
	else:
		push_warning("Puzzle_cidade: TextoObjetivo deve ser um Label ou RichTextLabel.")


## Monta o texto: objetivo primeiro, linha em branco, seção CURIOSIDADES e
## uma linha por curiosidade. Com usar_bbcode = true, o título da seção
## fica em negrito e azul-claro.
func _montar_texto_objetivo(usar_bbcode: bool) -> String:
	var titulo := TITULO_CURIOSIDADES
	if usar_bbcode:
		titulo = "[b][color=#%s]%s[/color][/b]" % [COR_AZUL_BRILHO.to_html(false), TITULO_CURIOSIDADES]

	var texto := TEXTO_OBJETIVO + "\n\n" + titulo
	for curiosidade in CURIOSIDADES:
		texto += "\n• " + curiosidade
	return texto


# --- Lógica dos slots ----------------------------------------------------------

## Chamado quando o jogador clica em uma opção disponível.
## Coloca a opção no primeiro slot vazio e desabilita o botão dela.
func _on_opcao_pressionada(nome_opcao: String) -> void:
	var indice_slot_vazio := slot_conteudo.find("")
	if indice_slot_vazio == -1:
		# Todos os slots já estão preenchidos; não há onde colocar.
		return

	slot_conteudo[indice_slot_vazio] = nome_opcao
	slots[indice_slot_vazio].text = OPCOES[nome_opcao]
	_atualizar_estilo_slot(indice_slot_vazio)

	var botao: Button = botoes_opcoes[nome_opcao]
	botao.disabled = true


## Chamado quando o jogador clica em um slot (para remover o que estiver nele).
## Slots vazios clicados não fazem nada. O slot removido fica vazio e NÃO
## reorganiza os outros slots.
func _on_slot_pressionado(indice: int) -> void:
	var nome_opcao := slot_conteudo[indice]
	if nome_opcao == "":
		return

	slot_conteudo[indice] = ""
	slots[indice].text = ""
	_atualizar_estilo_slot(indice)

	var botao: Button = botoes_opcoes[nome_opcao]
	botao.disabled = false


# --- Verificação do código montado ---------------------------------------------

func _on_botao_executar_pressed() -> void:
	if slot_conteudo.has(""):
		feedback_label.text = FEEDBACK_INCOMPLETO
		return

	var textos_montados: Array[String] = []
	for nome_opcao in slot_conteudo:
		textos_montados.append(OPCOES[nome_opcao])

	if textos_montados == RESPOSTA_CORRETA:
		feedback_label.text = FEEDBACK_CORRETO
		_concluir_puzzle()
	else:
		feedback_label.text = FEEDBACK_INCORRETO


## Avisa o resto do projeto (PC / GameManager) que o puzzle foi concluído,
## seguindo o mesmo sinal usado pelos outros puzzles do CodePlay.
func _concluir_puzzle() -> void:
	if puzzle_ja_concluido:
		return
	puzzle_ja_concluido = true
	desafio_concluido.emit()
