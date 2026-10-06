extends Control

## ============================================================
## Puzzle_Objetos.gd
## Fase "Objetos" — ensina a sintaxe de objetos em JavaScript.
## Desafio único: montar a criação do objeto "jogador".
## Mantém a mesma mecânica de clique dos demais puzzles do CodePlay:
## clicar numa opção preenche a próxima lacuna vazia; clicar numa
## lacuna preenchida devolve a opção ao botão de origem.
## O botão Limpar restaura o desafio ao estado inicial, sem concluir.
##
## ATUALIZAÇÃO VISUAL: estilização totalmente refeita (seção 8),
## usando como referência a linguagem visual do Puzzle_IfElse (Caverna
## de Cristal), mas trocando a identidade roxa pela identidade
## marrom/bronze das Ruínas. Nenhuma linha de LÓGICA foi alterada —
## apenas foram adicionadas chamadas de atualização visual (para
## diferenciar lacunas vazias/preenchidas) nos mesmos pontos em que o
## Puzzle_IfElse já faz isso, exatamente como o padrão de referência.
## ============================================================

signal desafio_concluido

# ------------------------------------------------------------
# 1. Constantes
# ------------------------------------------------------------

const MSG_TODAS_LACUNAS_PREENCHIDAS := "Todas as lacunas já estão preenchidas!"
const MSG_LACUNAS_INCOMPLETAS := "Preencha todas as lacunas antes de executar."
const MSG_ENTRADA_INCORRETA := "O código digitado não está correto. Revise \"let jogador\" e tente novamente."
const MSG_RESPOSTA_INCORRETA := "Algumas respostas estão incorretas. Revise as lacunas e tente novamente."
const MSG_PUZZLE_CONCLUIDO := "Parabéns! Você montou o objeto \"jogador\" corretamente."

const TEXTO_ENTRADA_ESPERADO := "let jogador"

# Ordem das lacunas: Lacuna1=nome, Lacuna2="Pedro", Lacuna3=17, Lacuna4=true
# "idade" e "ativo" são propriedades fixas (texto fixo), não são lacunas.
const RESPOSTAS_CORRETAS: Array[String] = [
	"nome",
	"\"Pedro\"",
	"17",
	"true"
]
const TEXTOS_OPCOES: Array[String] = [
	"idade",
	"true",
	"nome",
	"17",
	"\"Pedro\"",
	"ativo"
]

## ------------------------------------------------------------------
## Paleta visual do tema "Ruínas" (MARROM + BRONZE + BEGE ENVELHECIDO).
## Segue a MESMA hierarquia de cores usada no Puzzle_IfElse (que usa
## roxo), trocando o roxo por tons terrosos/bronze. As áreas grandes
## continuam escuras (marrom quase preto); o bronze aparece em bordas,
## títulos, destaques, hover, focus, pressed e lacunas — nunca
## preenchendo a tela inteira.
## ------------------------------------------------------------------

const COR_FUNDO: Color = Color("#0D0804")            # marrom quase preto — fundo geral
const COR_PAINEL: Color = Color("#160E07")           # marrom muito escuro — fundo dos painéis
const COR_BOTAO: Color = Color("#140C06")            # quase preto — fundo normal dos botões
const COR_BRONZE: Color = Color("#B08D57")           # bronze principal (bordas)
const COR_BRONZE_BRILHO: Color = Color("#E8CC96")    # bronze/bege mais brilhante (hover/focus)
const COR_MARROM_APAGADO: Color = Color("#4A3620")   # marrom discreto (lacuna vazia / disabled)
const COR_MARROM_ESCURO: Color = Color("#241708")    # tom escuro para o hover parcial
const COR_MARROM_FORTE: Color = Color("#6B4423")     # bronze/marrom mais forte (pressed)
const COR_TEXTO: Color = Color("#EDE0C8")            # bege envelhecido — texto principal
const COR_TEXTO_DESABILITADO: Color = Color("#7A6A52")

const RAIO_BORDA: int = 6
const ESPESSURA_BORDA_PAINEL: int = 2

# ------------------------------------------------------------
# 2. Referências de nós (@onready)
# ------------------------------------------------------------

@onready var entrada_codigo: LineEdit = $PainelCodigo/EntradaCodigo
@onready var lacuna_1: Button = $PainelCodigo/Lacuna1
@onready var lacuna_2: Button = $PainelCodigo/Lacuna2
@onready var lacuna_3: Button = $PainelCodigo/Lacuna3
@onready var lacuna_4: Button = $PainelCodigo/Lacuna4

@onready var texto_objetivo: RichTextLabel = $PainelObjetivo/TextoObjetivo

@onready var opcao_1: Button = $PainelOpcoes/Opcao1
@onready var opcao_2: Button = $PainelOpcoes/Opcao2
@onready var opcao_3: Button = $PainelOpcoes/Opcao3
@onready var opcao_4: Button = $PainelOpcoes/Opcao4
@onready var opcao_5: Button = $PainelOpcoes/Opcao5
@onready var opcao_6: Button = $PainelOpcoes/Opcao6

@onready var texto_dica: RichTextLabel = $PainelDica/TextoDica

@onready var feedback: Label = $Feedback
@onready var botao_executar: Button = $BotaoExecutar
@onready var botao_limpar: Button = $BotaoLimpar

# ------------------------------------------------------------
# 3. Estado interno
# ------------------------------------------------------------

# As 4 lacunas do desafio, na ordem em que devem ser preenchidas.
var _lacunas: Array[Button] = []
var _opcoes: Array[Button] = []

# Valor atual de cada lacuna ("" quando vazia).
var _valor_lacuna: Dictionary = {}
# Botão de opção que originou o valor de cada lacuna (null quando vazia).
var _origem_lacuna: Dictionary = {}

# Impede que desafio_concluido seja emitido mais de uma vez e que o puzzle
# continue reagindo a cliques depois de já ter sido resolvido.
var _concluido: bool = false

# Painéis dos quais o script guarda referência apenas para aplicar o
# estilo visual (bordas/fundo). Não interferem na lógica do puzzle.
@onready var _painel_codigo: Panel = $PainelCodigo
@onready var _painel_objetivo: Panel = $PainelObjetivo
@onready var _painel_opcoes: Panel = $PainelOpcoes
@onready var _painel_dica: Panel = $PainelDica

# ------------------------------------------------------------
# 4. Ciclo de vida
# ------------------------------------------------------------

func _ready() -> void:
	_lacunas = [lacuna_1, lacuna_2, lacuna_3, lacuna_4]
	_opcoes = [opcao_1, opcao_2, opcao_3, opcao_4, opcao_5, opcao_6]

	for lacuna in _lacunas:
		_conectar_botao(lacuna, _on_lacuna_pressionada.bind(lacuna))
	for opcao in _opcoes:
		_conectar_botao(opcao, _on_opcao_pressionada.bind(opcao))
	_conectar_botao(botao_executar, _on_executar_pressionado)
	_conectar_botao(botao_limpar, _on_limpar_pressionado)

	_configurar_desafio()
	_aplicar_estilo_visual()


func _conectar_botao(botao: Button, callable_ref: Callable) -> void:
	if not botao.pressed.is_connected(callable_ref):
		botao.pressed.connect(callable_ref)

# ------------------------------------------------------------
# 5. Configuração do desafio único
# ------------------------------------------------------------

func _configurar_desafio() -> void:
	_concluido = false
	feedback.text = ""

	texto_objetivo.text = "Monte a criação do objeto \"jogador\" preenchendo as lacunas com os valores corretos."
	texto_dica.text = "Uma propriedade vem antes dos dois pontos. Texto usa aspas duplas, números não usam aspas e valores booleanos usam true ou false."

	entrada_codigo.text = ""
	entrada_codigo.editable = true
	entrada_codigo.visible = true

	for lacuna in _lacunas:
		lacuna.text = ""
		lacuna.visible = true
		lacuna.disabled = false
		_valor_lacuna[lacuna] = ""
		_origem_lacuna[lacuna] = null
		_atualizar_estilo_lacuna(lacuna, false)

	for i in range(_opcoes.size()):
		_opcoes[i].text = TEXTOS_OPCOES[i]
		_opcoes[i].visible = true
		_opcoes[i].disabled = false

# ------------------------------------------------------------
# 6. Interação: opções e lacunas
# ------------------------------------------------------------

func _on_opcao_pressionada(opcao: Button) -> void:
	if _concluido:
		return

	var lacuna_vazia: Button = _buscar_proxima_lacuna_vazia()
	if lacuna_vazia == null:
		feedback.text = MSG_TODAS_LACUNAS_PREENCHIDAS
		return

	_valor_lacuna[lacuna_vazia] = opcao.text
	_origem_lacuna[lacuna_vazia] = opcao
	lacuna_vazia.text = opcao.text
	_atualizar_estilo_lacuna(lacuna_vazia, true)

	opcao.disabled = true
	opcao.visible = false

	feedback.text = ""


func _on_lacuna_pressionada(lacuna: Button) -> void:
	if _concluido:
		return
	if String(_valor_lacuna.get(lacuna, "")) == "":
		return

	var origem: Button = _origem_lacuna.get(lacuna)
	if origem != null:
		origem.disabled = false
		origem.visible = true

	_valor_lacuna[lacuna] = ""
	_origem_lacuna[lacuna] = null
	lacuna.text = ""
	_atualizar_estilo_lacuna(lacuna, false)


func _buscar_proxima_lacuna_vazia() -> Button:
	for lacuna in _lacunas:
		if String(_valor_lacuna.get(lacuna, "")) == "":
			return lacuna
	return null


func _todas_lacunas_preenchidas() -> bool:
	for lacuna in _lacunas:
		if String(_valor_lacuna.get(lacuna, "")) == "":
			return false
	return true

# ------------------------------------------------------------
# 7. Validação e conclusão
# ------------------------------------------------------------

func _on_executar_pressionado() -> void:
	if _concluido:
		return

	if not _validar_entrada_codigo(entrada_codigo.text):
		feedback.text = MSG_ENTRADA_INCORRETA
		return

	if not _todas_lacunas_preenchidas():
		feedback.text = MSG_LACUNAS_INCOMPLETAS
		return

	if not _validar_lacunas():
		feedback.text = MSG_RESPOSTA_INCORRETA
		return

	_concluir_desafio()


## Restaura o desafio ao estado inicial (campo de entrada, lacunas e opções),
## sem avançar nem concluir o puzzle — mesmo padrão do botão Limpar usado
## em outros puzzles do projeto (ex.: Puzzle_Loops).
func _on_limpar_pressionado() -> void:
	if _concluido:
		return
	_configurar_desafio()


func _validar_entrada_codigo(texto: String) -> bool:
	return _normalizar_texto(texto) == TEXTO_ENTRADA_ESPERADO


func _normalizar_texto(texto: String) -> String:
	var partes := texto.strip_edges().split(" ", false)
	return " ".join(partes)


func _validar_lacunas() -> bool:
	for i in range(_lacunas.size()):
		var valor := String(_valor_lacuna.get(_lacunas[i], ""))
		if valor != RESPOSTAS_CORRETAS[i]:
			return false
	return true


func _concluir_desafio() -> void:
	_concluido = true
	feedback.text = MSG_PUZZLE_CONCLUIDO

	entrada_codigo.editable = false
	for lacuna in _lacunas:
		lacuna.disabled = true
	for opcao in _opcoes:
		opcao.disabled = true

	desafio_concluido.emit()


# ==================================================================
# 8. VISUAL — TEMA "RUÍNAS" (marrom/bronze)
# ==================================================================
# Aplica apenas theme overrides (cores, styleboxes) e propriedades
# visuais nos nós já existentes. Não cria nenhum nó novo, não altera
# posição, tamanho, nomes ou estrutura da cena, e não interfere em
# nenhuma regra de validação ou mecânica do puzzle.
#
# A abordagem segue diretamente a usada no Puzzle_IfElse (Caverna de
# Cristal): uma função central _caixa() para gerar StyleBoxFlat com
# bordas arredondadas e brilho opcional, estilos separados para os
# estados normal/hover/pressed/focus/disabled, hover PARCIAL (o botão
# continua majoritariamente escuro, só ganhando uma faixa e uma borda
# mais brilhante), e lacunas com aparência diferente quando vazias e
# quando preenchidas. A única troca é a paleta: roxo -> marrom/bronze.

## Cria um StyleBoxFlat completo.
## - largura: espessura da borda em todos os lados;
## - brilho: tamanho do glow/sombra bronze (efeito de luz); 0 = sem brilho;
## - largura_esq / largura_baixo: espessura extra só nesses lados (faixa
##   parcial usada no hover, para não pintar o botão inteiro);
## - margem_h / margem_v: margens internas (-1 mantém o padrão do nó).
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
		sb.shadow_color = Color(COR_BRONZE.r, COR_BRONZE.g, COR_BRONZE.b, 0.35)
		sb.shadow_size = brilho
		sb.shadow_offset = Vector2.ZERO
	if margem_h >= 0:
		sb.content_margin_left = margem_h
		sb.content_margin_right = margem_h
	if margem_v >= 0:
		sb.content_margin_top = margem_v
		sb.content_margin_bottom = margem_v
	return sb


## Contorno de foco: só a borda, sem preencher o botão/campo — mantém o
## fundo escuro visível mesmo quando o elemento está focado.
func _caixa_foco() -> StyleBoxFlat:
	var sb := _caixa(Color(0, 0, 0, 0), COR_BRONZE_BRILHO, 2)
	sb.draw_center = false
	return sb


## Aplica os estilos de cada estado e as cores de texto a um Button.
func _definir_estilos_botao(
		botao: Button,
		normal: StyleBox,
		hover: StyleBox,
		pressed: StyleBox,
		foco: StyleBox,
		desabilitado: StyleBox,
		cor_texto: Color
) -> void:
	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressed)
	botao.add_theme_stylebox_override("hover_pressed", pressed)
	botao.add_theme_stylebox_override("focus", foco)
	botao.add_theme_stylebox_override("disabled", desabilitado)

	for nome_cor in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color"
	]:
		botao.add_theme_color_override(nome_cor, cor_texto)
	botao.add_theme_color_override("font_disabled_color", COR_TEXTO_DESABILITADO)


func _aplicar_estilo_visual() -> void:
	_aplicar_borda_paineis()
	_aplicar_estilo_entrada_codigo()
	_aplicar_estilo_botoes_opcoes()
	_aplicar_estilo_lacunas()
	_aplicar_estilo_botoes_acao()
	_aplicar_estilo_textos()


## Borda bronze arredondada com leve brilho em PainelCodigo,
## PainelObjetivo, PainelOpcoes e PainelDica — fundo sempre COR_PAINEL
## (marrom bem escuro), igual à abordagem de painéis do Puzzle_IfElse.
func _aplicar_borda_paineis() -> void:
	var paineis: Array[Panel] = [_painel_codigo, _painel_objetivo, _painel_opcoes, _painel_dica]
	for painel: Panel in paineis:
		if painel == null:
			continue
		painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_BRONZE, ESPESSURA_BORDA_PAINEL, 6))


## EntradaCodigo continua sendo o único campo digitado pelo jogador.
## Recebe o mesmo tratamento visual de um botão normal (fundo escuro,
## borda bronze), com destaque de foco (fundo levemente marrom-escuro,
## borda brilhante) enquanto o jogador digita.
func _aplicar_estilo_entrada_codigo() -> void:
	if entrada_codigo == null:
		return
	var normal := _caixa(COR_BOTAO, COR_BRONZE, 2, 0, -1, -1, 10, 6)
	var foco := _caixa(COR_MARROM_ESCURO, COR_BRONZE_BRILHO, 2, 6, -1, -1, 10, 6)
	entrada_codigo.add_theme_stylebox_override("normal", normal)
	entrada_codigo.add_theme_stylebox_override("focus", foco)
	entrada_codigo.add_theme_color_override("font_color", COR_TEXTO)
	entrada_codigo.add_theme_color_override("font_placeholder_color", COR_MARROM_APAGADO)
	entrada_codigo.add_theme_color_override("caret_color", COR_BRONZE_BRILHO)


## Botões de opção do PainelOpcoes (idade/true/nome/17/"Pedro"/ativo):
## mesmo estilo padrão usado nos botões de ação (ver
## _estilizar_botao_padrao), para que toda a janela fale a mesma
## linguagem visual.
func _aplicar_estilo_botoes_opcoes() -> void:
	for opcao: Button in _opcoes:
		if opcao == null:
			continue
		_estilizar_botao_padrao(opcao)


## BotaoExecutar e BotaoLimpar recebem o mesmo tratamento padrão dos
## botões de opção, mantendo a interface inteira consistente.
func _aplicar_estilo_botoes_acao() -> void:
	if botao_executar != null:
		_estilizar_botao_padrao(botao_executar)
	if botao_limpar != null:
		_estilizar_botao_padrao(botao_limpar)


## Estilo padrão compartilhado por botões de opção e pelos botões de
## ação (Executar/Limpar):
##   NORMAL: fundo quase preto, borda bronze fina, texto bege claro;
##   HOVER (parcial): fundo ainda majoritariamente escuro, ganhando um
##     tom marrom-escuro e uma faixa mais grossa à esquerda/embaixo,
##     borda mais brilhante e glow discreto — nunca pinta o botão
##     inteiro;
##   PRESSED: bronze/marrom mais forte, claramente diferente do hover;
##   FOCUS: só a borda brilhante, sem destruir o fundo escuro;
##   DISABLED: marrom apagado, texto menos intenso.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_BRONZE, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_MARROM_ESCURO, COR_BRONZE_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_MARROM_FORTE, COR_BRONZE, 2, 0, -1, -1, 10, 6)
	var desabilitado := _caixa(COR_FUNDO, COR_MARROM_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos_botao(botao, normal, hover, pressed, _caixa_foco(), desabilitado, COR_TEXTO)


## Aplica o estado visual inicial das 4 lacunas de acordo com o
## conteúdo atual de cada uma. Chamada uma vez em
## _aplicar_estilo_visual(); depois disso, cada clique de opção/lacuna
## chama diretamente _atualizar_estilo_lacuna() (seções 5 e 6) para
## manter a aparência sincronizada com os dados.
func _aplicar_estilo_lacunas() -> void:
	for lacuna: Button in _lacunas:
		if lacuna == null:
			continue
		_atualizar_estilo_lacuna(lacuna, String(_valor_lacuna.get(lacuna, "")) != "")


## Redesenha UMA lacuna no estado vazio ou preenchido, igual à lógica
## dos slots do Puzzle_IfElse:
##   VAZIA: fundo marrom quase preto, borda bronze apagada, texto
##     discreto;
##   PREENCHIDA: fundo marrom quase preto, borda bronze mais forte com
##     brilho, texto em bege/bronze claro, hover mais destacado (mesmo
##     hover parcial dos botões).
## Puramente visual — não interfere em como/quando uma lacuna é
## preenchida ou esvaziada (isso continua 100% nas seções 5 e 6).
func _atualizar_estilo_lacuna(lacuna: Button, preenchida: bool) -> void:
	if lacuna == null:
		return
	if not preenchida:
		var normal := _caixa(COR_FUNDO, COR_MARROM_APAGADO, 1, 0, -1, -1, 10, 6)
		var hover := _caixa(COR_FUNDO, COR_BRONZE, 2, 0, -1, -1, 10, 6)
		_definir_estilos_botao(lacuna, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO_DESABILITADO)
	else:
		var normal := _caixa(COR_FUNDO, COR_BRONZE, 3, 8, -1, -1, 10, 6)
		var hover := _caixa(COR_MARROM_ESCURO, COR_BRONZE_BRILHO, 3, 10, 7, 6, 10, 6)
		var pressed := _caixa(COR_MARROM_FORTE, COR_BRONZE, 3, 0, -1, -1, 10, 6)
		_definir_estilos_botao(lacuna, normal, hover, pressed, _caixa_foco(), normal, COR_BRONZE_BRILHO)


## TextoObjetivo, TextoDica e Feedback: cores de texto coerentes com a
## paleta bege/bronze envelhecida das Ruínas. Apenas a cor da fonte é
## ajustada — nenhum conteúdo/texto é alterado.
func _aplicar_estilo_textos() -> void:
	if texto_objetivo != null:
		texto_objetivo.add_theme_color_override("default_color", COR_BRONZE_BRILHO)
	if texto_dica != null:
		texto_dica.add_theme_color_override("default_color", COR_TEXTO)
	if feedback != null:
		feedback.add_theme_color_override("font_color", COR_TEXTO)
