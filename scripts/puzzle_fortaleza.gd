extends Control
## Script do Puzzle_Fortaleza — desafios de loop FOR e WHILE.
## Godot 4.7 | GDScript
##
## Regras principais:
## - Qualquer botão de PainelOpcoes pode ser colocado em QUALQUER slot do
##   desafio ativo, correto ou não — vai sempre para o primeiro slot vazio.
##   Nenhum bloco é filtrado ou rejeitado por "não pertencer" ao desafio.
## - O slot exibe o TEXTO VISÍVEL do botão (opcao.text), mas a identificação
##   interna da opção usada na validação continua sendo o nome do Node
##   (opcao.name), guardado em _estado_for/_estado_while e em
##   _opcao_no_slot — por isso a validação não é afetada mesmo que o texto
##   visível seja diferente do nome do nó.
## - Testar verifica o estado ATUAL de FOR e WHILE, reconhece um desafio
##   como concluído assim que ele estiver correto (preservando o progresso),
##   simula o resultado no TextoFeedback e avança FOR -> WHILE
##   automaticamente. NUNCA finaliza o puzzle nem emite desafio_concluido.
## - Executar é quem confirma: repete a mesma verificação/avanço de Testar,
##   mas SÓ finaliza o puzzle (e emite desafio_concluido, uma única vez)
##   quando FOR e WHILE já estiverem corretos.

signal desafio_concluido

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO — RESPOSTAS CORRETAS
# ---------------------------------------------------------------------------
# Chaves = nome INTERNO do slot (usado em ORDEM_SLOTS_*, RESPOSTA_* e no
# dicionário de estado) — não precisa bater com o nome real do Node na cena.
# Valores = nome do Node (opcao.name) esperado nesse slot — NÃO o texto
# visível. A validação compara sempre por nome de nó.
#
# Solução esperada para o desafio FOR (sequência 1 até 10):
#   let quantidade = 10;
#   for (i = 1; i <= quantidade; i++) {
#       console.log(i);
#   }
#
# O botão de condição do FOR em PainelOpcoes já se chama "Condicao"
# (Node.name) — não precisa ser renomeado. Só o .text visível dele deve
# ser atualizado no editor para mostrar a condição correta
# ("i = 1; i <= quantidade; i++"), já que o slot exibe opcao.text, não
# opcao.name.
const RESPOSTA_FOR := {
	"SlotFOR": "FOR",
	"SlotCondicao": "Condicao",
	"Slotconsole_log(i)": "Console_log(i)",
}

# Declaração de variável exigida no TextEdit de cada desafio (validada como
# parte obrigatória de _validar(), junto com os slots).
const RESPOSTA_VAR_FOR := "let quantidade = 10;"

# Solução esperada para o desafio WHILE (sequência infinita crescente):
#   let runa = 1;
#   while (runa > 0) {
#       console.log(runa);
#       runa++;
#   }
#
# O botão "runa < 0" em PainelOpcoes foi renomeado (Node.name e .text) para
# "runa > 0", e o botão "GTA6" foi renomeado (Node.name e .text) para
# "runa++" — nenhum decoy novo foi criado, ambos reaproveitam nós que já
# existiam na cena.
const RESPOSTA_WHILE := {
	"SlotWhile": "WHILE",
	"Condicao": "runa > 0",
	"Console_log(runa)": "(console_log(runa)",
	"SlotIncremento": "runa++",
}

const RESPOSTA_VAR_WHILE := "let runa = 1;"

# Ordem de preenchimento (primeiro slot vazio) de cada desafio.
const ORDEM_SLOTS_FOR := ["SlotFOR", "SlotCondicao", "Slotconsole_log(i)"]
const ORDEM_SLOTS_WHILE := ["SlotWhile", "Condicao", "Console_log(runa)", "SlotIncremento"]

const TITULO_FOR := "DESAFIO: FOR"
const TITULO_WHILE := "DESAFIO: WHILE"
const INSTRUCAO_FOR := "Defina uma variável chamada quantidade e crie uma sequência dos números 1 até 10 usando o laço for."
const INSTRUCAO_WHILE := "Defina uma variável chamada runa e crie uma sequência infinita de números usando o laço while."
const PLACEHOLDER := "___"

# ---------------------------------------------------------------------------
# PAINELINFORMACOES — CONTEÚDO EDUCATIVO POR DESAFIO
# ---------------------------------------------------------------------------
# Cada bloco explica o CONCEITO do laço (o que é, estrutura genérica, o que
# cada parte faz e uma dica de raciocínio) sem nunca revelar a ordem ou o
# conteúdo exato dos blocos corretos do puzzle. Isso é combinado, na hora de
# exibir, com o objetivo geral do desafio e com a instrução específica dele
# (INSTRUCAO_FOR/INSTRUCAO_WHILE), que continua aparecendo junto.
const INFO_TITULO := "INFORMAÇÕES ÚTEIS"

const INFO_FOR_EXPLICACAO := "O laço FOR é usado quando você quer repetir uma ação várias vezes seguindo uma sequência ou quantidade determinada."
const INFO_FOR_ESTRUTURA := "for (início; condição; atualização) {\n    // código que será repetido\n}"
const INFO_FOR_PONTOS: Array[String] = [
	"início → define onde a contagem começa.",
	"condição → determina quando o laço continua.",
	"atualização → altera o valor a cada repetição.",
]
const INFO_FOR_DICA := "Observe com atenção a variável usada para controlar a repetição e a condição que determina quando o laço deve parar."
const INFO_FOR_OBJETIVO := "Criar uma sequência de números usando um laço FOR."

const INFO_WHILE_EXPLICACAO := "O laço WHILE repete uma ação enquanto uma condição for verdadeira."
const INFO_WHILE_ESTRUTURA := "while (condição) {\n    // código que será repetido\n}"
const INFO_WHILE_PONTOS: Array[String] = [
	"condição → controla se o laço continua executando.",
	"enquanto a condição for verdadeira, o código continua sendo repetido.",
	"uma alteração dentro do laço pode fazer a condição mudar.",
]
const INFO_WHILE_DICA := "Pense no que precisa acontecer para que a repetição continue e como uma variável pode controlar esse processo."
const INFO_WHILE_OBJETIVO := "Criar uma sequência usando um laço WHILE."

# ---------------------------------------------------------------------------
# ESTÉTICA — COR ÚNICA DE DESTAQUE (bordas dos painéis + hover dos botões)
# ---------------------------------------------------------------------------
const COR_BORDA := Color("8b0000") # vermelho escuro — bordas dos painéis e hover dos blocos/slots
const LARGURA_BORDA_PAINEL := 3

# ---------------------------------------------------------------------------
# ESTÉTICA — TEXTOS (tudo branco, sem contorno)
# ---------------------------------------------------------------------------
const COR_TEXTO := Color("ffffff")

# ---------------------------------------------------------------------------
# ESTÉTICA — BOTÕES (opções, slots e botões de ação)
# ---------------------------------------------------------------------------
const COR_BOTAO_FUNDO := Color("2a0f0f")
const COR_BOTAO_FUNDO_PRESSED := Color("1a0808")
const COR_BOTAO_FUNDO_DISABLED := Color("1f1010")

const COR_BOTAO_BORDA_NORMAL := Color("4a1515")
const COR_BOTAO_BORDA_HOVER := COR_BORDA
const COR_BOTAO_BORDA_PRESSED := Color("e8b463")
const COR_BOTAO_BORDA_DISABLED := Color("3a2020")

const BORDA_LARGURA_NORMAL := 2
const BORDA_LARGURA_HOVER := 3
const RAIO_CANTO_BOTAO := 6

# ---------------------------------------------------------------------------
# ESTÉTICA — POLIMENTO (dourado de destaque, fundo dos painéis, e paletas
# específicas para diferenciar TextEdit / Slots / Opções / hierarquia dos
# botões de ação). Nada aqui muda posição, tamanho ou lógica — só aparência.
# ---------------------------------------------------------------------------
const COR_DOURADO := Color("d4af37") # dourado — destaque de foco/preenchido/CTA
const COR_DOURADO_CLARO := Color("f4d03f")

# Fundo aplicado aos painéis que não têm StyleBox própria definida no editor
# (antes ficavam totalmente transparentes) — dá a cada seção uma "caixa"
# visualmente delimitada, mantendo a borda vermelha já existente.
const COR_PAINEL_FUNDO := Color(0.078, 0.027, 0.027, 0.9)
const RAIO_CANTO_PAINEL := 4

# PainelOpcoes: botões com cara de "bloco/runa" (canto mais arredondado + leve
# sombra), para não parecer igual aos slots.
const RAIO_CANTO_OPCAO := 10
const COR_SOMBRA_OPCAO := Color(0, 0, 0, 0.35)

# Slots: aparência de "encaixe" — visual diferente conforme vazio (___,
# borda discreta) ou preenchido (destaque dourado), sem mexer na lógica de
# preenchimento/remoção.
const COR_SLOT_VAZIO_FUNDO := Color("170a0a")
const COR_SLOT_VAZIO_BORDA := Color("4a2020")
const COR_SLOT_PREENCHIDO_FUNDO := Color("2a1810")
const COR_SLOT_PREENCHIDO_BORDA := COR_DOURADO

# TextEdit (declaração de variável): visual de terminal/editor de código.
const COR_TEXTEDIT_FUNDO := Color("120808")
const COR_TEXTEDIT_BORDA := Color("4a1515")
const COR_TEXTEDIT_BORDA_FOCO := COR_DOURADO
const PADDING_TEXTEDIT := 10

# Hierarquia dos botões de ação: Executar (primário/dourado), Testar
# (mantém o estilo padrão já existente) e Limpar (secundário/discreto).
const COR_EXECUTAR_FUNDO := Color("3a2408")
const COR_EXECUTAR_FUNDO_PRESSED := Color("281905")
const COR_EXECUTAR_BORDA := COR_DOURADO
const COR_EXECUTAR_BORDA_HOVER := COR_DOURADO_CLARO
const BORDA_LARGURA_EXECUTAR := 3

const COR_LIMPAR_FUNDO := Color("201313")
const COR_LIMPAR_FUNDO_PRESSED := Color("160d0d")
const COR_LIMPAR_BORDA := Color("5a4040")
const COR_LIMPAR_BORDA_HOVER := Color("7a5a5a")

# ---------------------------------------------------------------------------
# NODES (PainelWhile agora também tem o Node "SlotIncremento", adicionado
# na cena para o novo campo "runa++;"; nenhum outro Node novo, nenhum outro
# renomeado)
# ---------------------------------------------------------------------------
@onready var janela_puzzle: Control = $JanelaPuzzle
@onready var titulo: Label = $JanelaPuzzle/BarraTitulo/Titulo
@onready var painel_informacoes: Control = $JanelaPuzzle/PainelInformacoes
@onready var texto_informacoes: Control = $JanelaPuzzle/PainelInformacoes/TextoInformacoes
@onready var titulo_informacoes: Control = $JanelaPuzzle/PainelInformacoes/TituloInformacoes
@onready var texto_feedback: Control = $JanelaPuzzle/TextoFeedback

# Barra de rolagem visível do TextoFeedback. OPCIONAL: se o Node ainda não
# existir na cena, fica null e o scroll continua funcionando só pela roda
# do mouse, como antes (ver _configurar_scroll_feedback/_aplicar_scroll_feedback).
@onready var scroll_feedback: VScrollBar = get_node_or_null("JanelaPuzzle/ScrollFeedback")

@onready var painel_for: Control = $JanelaPuzzle/PainelFOR
@onready var painel_while: Control = $JanelaPuzzle/PainelWhile

# TextEdit da declaração de variável de cada desafio (obrigatório na validação).
@onready var texto_var_for: TextEdit = $JanelaPuzzle/PainelFOR/TextEdit
@onready var texto_var_while: TextEdit = $JanelaPuzzle/PainelWhile/TextEdit

@onready var painel_opcoes: Control = $JanelaPuzzle/PainelOpcoes
@onready var painel_botoes: Control = $PainelBotoes

@onready var btn_executar: Button = $PainelBotoes/Executar
@onready var btn_limpar: Button = $PainelBotoes/Limpar
@onready var btn_testar: Button = $PainelBotoes/Testar

# Slots por desafio: nome do slot -> Node do slot
var _slots_for: Dictionary = {}
var _slots_while: Dictionary = {}

# Estado preenchido de cada desafio: nome do slot -> NOME DO NODE (opcao.name)
# da opção colocada (ou "" se vazio). Usado só para validação interna.
var _estado_for: Dictionary = {}
var _estado_while: Dictionary = {}

# Qual opção (Node dentro de PainelOpcoes) está em qual slot.
# Chave = "FOR:SlotFOR", "WHILE:Condicao" etc. -> Node da opção
var _opcao_no_slot: Dictionary = {}

var _desafio_ativo: String = "FOR"
var _for_resolvido: bool = false
var _while_resolvido: bool = false
var _puzzle_resolvido: bool = false

# ---------------------------------------------------------------------------
# ROLAGEM MANUAL DE PainelInformacoes (TextoInformacoes é um Label comum,
# sem rolagem nativa) — ver _configurar_painel_informacoes/_aplicar_scroll_informacoes.
# ---------------------------------------------------------------------------
# Posição Y original de TextoInformacoes (a definida no editor), usada como
# topo (offset 0) da rolagem.
var _texto_informacoes_y_base: float = 0.0
# Deslocamento atual da rolagem (0 = topo do texto).
var _scroll_informacoes_offset: float = 0.0
# Deslocamento máximo permitido (0 quando o conteúdo já cabe sem rolar).
var _scroll_informacoes_max: float = 0.0
const VELOCIDADE_SCROLL_INFORMACOES := 40.0

# ---------------------------------------------------------------------------
# ROLAGEM MANUAL DE TextoFeedback (mesma técnica de PainelInformacoes: o
# Label desenha o texto inteiro e sua posição Y é deslocada; ver
# _configurar_scroll_feedback/_aplicar_scroll_feedback).
# ---------------------------------------------------------------------------
var _texto_feedback_y_base: float = 0.0
var _scroll_feedback_offset: float = 0.0
var _scroll_feedback_max: float = 0.0
const VELOCIDADE_SCROLL_FEEDBACK := 40.0
# Evita loop: true enquanto o próprio script está ajustando o VScrollBar
# (para não disparar _on_scroll_feedback_value_changed de volta).
var _sincronizando_scroll_feedback: bool = false


func _ready() -> void:
	_slots_for = {
		"SlotFOR": painel_for.get_node("SlotFOR"),
		"SlotCondicao": painel_for.get_node("SlotCondicao"),
		"Slotconsole_log(i)": painel_for.get_node("Slotconsole_log(i)"),
	}
	_slots_while = {
		# Chave interna continua "SlotWhile" (usada em ORDEM_SLOTS_WHILE e
		# RESPOSTA_WHILE); o node em si foi renomeado para "While" na cena.
		"SlotWhile": painel_while.get_node("While"),
		"Condicao": painel_while.get_node("Condicao"),
		"Console_log(runa)": painel_while.get_node("Console_log(runa)"),
		# Novo slot para a linha "runa++;" do desafio WHILE.
		"SlotIncremento": painel_while.get_node("SlotIncremento"),
	}

	for chave in _slots_for.keys():
		_estado_for[chave] = ""
	for chave in _slots_while.keys():
		_estado_while[chave] = ""

	_conectar_opcoes()
	_conectar_slots()
	_conectar_botoes()
	_aplicar_estetica_puzzle()
	_configurar_texto_feedback()
	_configurar_scroll_feedback()
	_configurar_painel_informacoes()
	_atualizar_visual_todos_slots()
	_mudar_desafio_ativo("FOR")
	_set_texto(texto_feedback, "")


# ---------------------------------------------------------------------------
# ESTÉTICA — APLICAÇÃO (não mexe em lógica, sinais ou nomes de Node)
# ---------------------------------------------------------------------------
func _aplicar_estetica_puzzle() -> void:
	_aplicar_estilo_textos_recursivo(self)
	_aplicar_bordas_paineis()

	# PainelOpcoes: visual de "bloco/runa", diferente dos slots.
	for opcao in painel_opcoes.get_children():
		if opcao is BaseButton:
			_aplicar_estilo_opcao(opcao)

	# Slots: começam todos vazios (visual de "encaixe" vazio); o estilo
	# preenchido/vazio é atualizado depois, quando o jogador coloca ou
	# remove um bloco (ver _on_opcao_pressionada/_on_slot_pressionado/
	# _on_limpar_pressed/_atualizar_visual_todos_slots).
	for slot in _slots_for.values():
		if slot is BaseButton:
			_aplicar_estilo_slot_vazio(slot)
	for slot in _slots_while.values():
		if slot is BaseButton:
			_aplicar_estilo_slot_vazio(slot)

	# Hierarquia dos botões de ação: Executar em destaque (primário/dourado),
	# Testar mantém o estilo padrão já existente, Limpar fica discreto.
	_aplicar_estilo_botao(btn_testar)
	_aplicar_estilo_botao_executar(btn_executar)
	_aplicar_estilo_botao_limpar(btn_limpar)

	_aplicar_estilo_textedit()
	_aplicar_estilo_scrollbar_feedback()


# ---------------------------------------------------------------------------
# TEXTOFEEDBACK — CONFIGURAÇÃO DE OUTPUT/TERMINAL
# ---------------------------------------------------------------------------
# Ajusta apenas as propriedades de leitura do TextoFeedback (alinhamento,
# quebra de linha, corte de texto e rolagem quando disponível). NÃO altera
# tamanho, posição, cor ou nenhum outro nó — a cor branca e a ausência de
# contorno já são aplicadas por _aplicar_estilo_textos_recursivo() acima.
func _configurar_texto_feedback() -> void:
	if texto_feedback == null:
		return

	if texto_feedback is RichTextLabel:
		# RichTextLabel tem rolagem própria: ativa-se sem precisar de
		# nenhum ScrollContainer novo.
		texto_feedback.bbcode_enabled = false
		texto_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_feedback.scroll_active = true
		texto_feedback.scroll_following = true
		texto_feedback.fit_content = false
	elif texto_feedback is Label:
		# Label não tem rolagem nativa (exigiria criar um ScrollContainer,
		# o que foi proibido) — pelo menos garante que o texto não seja
		# cortado e quebre linha corretamente.
		texto_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texto_feedback.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		texto_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_feedback.clip_text = false
		texto_feedback.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


# Único ponto do script que escreve no TextoFeedback a partir de agora.
# Junta as linhas com quebra de linha e rola automaticamente até o final
# para sempre mostrar a saída mais recente (comportamento de terminal) —
# via rolagem nativa se for RichTextLabel, ou via _aplicar_scroll_feedback
# se for um Label comum.
func _mostrar_saida(linhas: PackedStringArray) -> void:
	_set_texto(texto_feedback, "\n".join(linhas))
	if texto_feedback is RichTextLabel:
		texto_feedback.scroll_to_line(texto_feedback.get_line_count())
	elif texto_feedback is Label:
		_aplicar_scroll_feedback(INF)


# ---------------------------------------------------------------------------
# ROLAGEM MANUAL DE TextoFeedback (TextoFeedback é um Label comum, sem
# rolagem nativa, e — diferente de TextoInformacoes — não tem um painel
# próprio dedicado ao seu redor na cena). Para o texto poder rolar sem
# vazar da janela SEM criar nenhum Node novo, a única propriedade que
# precisa ser ligada é clip_contents em JanelaPuzzle (o painel que já
# engloba toda a janela do puzzle); a partir daí a técnica é a mesma usada
# em PainelInformacoes: o Label desenha o texto inteiro (clip_text = false)
# e sua posição Y é deslocada para cima/baixo dentro da própria área que já
# tinha no editor (texto_feedback.size.y).
# ---------------------------------------------------------------------------
func _configurar_scroll_feedback() -> void:
	if texto_feedback == null or not (texto_feedback is Label):
		return

	_texto_feedback_y_base = texto_feedback.position.y

	if janela_puzzle is Control:
		janela_puzzle.clip_contents = true

	if not texto_feedback.gui_input.is_connected(_on_texto_feedback_gui_input):
		texto_feedback.gui_input.connect(_on_texto_feedback_gui_input)

	if scroll_feedback != null:
		scroll_feedback.min_value = 0.0
		scroll_feedback.step = 1.0
		if not scroll_feedback.value_changed.is_connected(_on_scroll_feedback_value_changed):
			scroll_feedback.value_changed.connect(_on_scroll_feedback_value_changed)


func _aplicar_scroll_feedback(offset: float) -> void:
	if texto_feedback == null or not (texto_feedback is Label):
		return

	var altura_conteudo: float = texto_feedback.get_minimum_size().y
	var altura_disponivel: float = texto_feedback.size.y
	_scroll_feedback_max = max(0.0, altura_conteudo - altura_disponivel)
	_scroll_feedback_offset = clamp(offset, 0.0, _scroll_feedback_max)
	texto_feedback.position.y = _texto_feedback_y_base - _scroll_feedback_offset

	if scroll_feedback != null:
		_sincronizando_scroll_feedback = true
		scroll_feedback.max_value = max(altura_conteudo, altura_disponivel)
		scroll_feedback.page = altura_disponivel
		scroll_feedback.value = _scroll_feedback_offset
		# Some invisível quando não há nada para rolar (conteúdo já cabe).
		scroll_feedback.visible = _scroll_feedback_max > 0.0
		_sincronizando_scroll_feedback = false


# Chamado quando o jogador arrasta a barra (ou clica nela) — não faz nada
# se a mudança veio do próprio script sincronizando (evita loop).
func _on_scroll_feedback_value_changed(valor: float) -> void:
	if _sincronizando_scroll_feedback:
		return
	_aplicar_scroll_feedback(valor)


# IMPORTANTE: no Inspector, "Mouse > Filter" de TextoFeedback precisa ser
# "Stop" (ou "Pass"), senão o Godot ignora o evento de roda do mouse por
# padrão (mesma observação já feita para PainelInformacoes e os slots).
func _on_texto_feedback_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_aplicar_scroll_feedback(_scroll_feedback_offset + VELOCIDADE_SCROLL_FEEDBACK)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_aplicar_scroll_feedback(_scroll_feedback_offset - VELOCIDADE_SCROLL_FEEDBACK)


# ---------------------------------------------------------------------------
# PAINELINFORMACOES — CONFIGURAÇÃO E MONTAGEM DE CONTEÚDO
# ---------------------------------------------------------------------------
# Garante que o conteúdo (bem mais longo que o espaço do painel) NUNCA
# apareça visualmente fora do PainelInformacoes, sem alterar posição ou
# tamanho de nenhum Node existente (TituloInformacoes, TextoInformacoes ou
# o próprio PainelInformacoes):
#   1) PainelInformacoes ganha clip_contents = true, então nada que seus
#      filhos desenhem fora do próprio retângulo fica visível, não importa
#      o tamanho do texto.
#   2) O título fixo "INFORMAÇÕES ÚTEIS" passa a usar só o TituloInformacoes
#      dedicado, em vez de também aparecer duplicado dentro do texto de
#      TextoInformacoes — reduzindo o conteúdo que precisa caber/rolar.
#   3) TextoInformacoes é um Label comum, sem rolagem nativa. Para o texto
#      continuar 100% legível sem vazar da caixa e sem precisar de um
#      ScrollContainer novo, ele é rolado MANUALMENTE com a roda do mouse
#      (ver _on_painel_informacoes_gui_input/_aplicar_scroll_informacoes):
#      o Label desenha o texto inteiro (clip_text = false) e sua posição Y
#      é deslocada para cima/baixo dentro do painel; o clip_contents do
#      painel esconde a parte que sai da área visível. Se um dia
#      TextoInformacoes virar um RichTextLabel, a rolagem nativa dele é
#      usada em vez da manual.
# Nenhum ScrollContainer novo é criado, nenhum Node é redimensionado ou
# reposicionado permanentemente, e nenhuma fonte é reduzida.
func _configurar_painel_informacoes() -> void:
	if texto_informacoes == null:
		return

	_texto_informacoes_y_base = texto_informacoes.position.y

	if painel_informacoes is Control:
		painel_informacoes.clip_contents = true
		if not painel_informacoes.gui_input.is_connected(_on_painel_informacoes_gui_input):
			painel_informacoes.gui_input.connect(_on_painel_informacoes_gui_input)

	_set_texto(titulo_informacoes, INFO_TITULO)

	if texto_informacoes is Label:
		texto_informacoes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texto_informacoes.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		texto_informacoes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Desenha o texto inteiro (não corta), mesmo que isso ultrapasse a
		# altura do próprio Label — quem garante que nada vaze da CAIXA é
		# o clip_contents do painel + a rolagem manual, não o clip_text.
		texto_informacoes.clip_text = false
		texto_informacoes.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	elif texto_informacoes is RichTextLabel:
		# Fallback caso TextoInformacoes seja trocado por um RichTextLabel
		# no futuro: usa a rolagem própria dele em vez da rolagem manual.
		texto_informacoes.bbcode_enabled = false
		texto_informacoes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_informacoes.fit_content = false
		texto_informacoes.scroll_active = true
		texto_informacoes.scroll_following = false


# Recalcula quanto o conteúdo atual de TextoInformacoes ultrapassa a altura
# visível do painel e aplica o deslocamento vertical pedido (clampeado entre
# 0 e o máximo permitido). Chamado sempre que o texto muda (nova troca de
# desafio) — com offset 0 volta pro topo — e a cada rolagem do mouse.
func _aplicar_scroll_informacoes(offset: float) -> void:
	if texto_informacoes == null or not (texto_informacoes is Label):
		return

	var altura_conteudo: float = texto_informacoes.get_minimum_size().y
	var altura_disponivel: float = painel_informacoes.size.y - _texto_informacoes_y_base
	_scroll_informacoes_max = max(0.0, altura_conteudo - altura_disponivel)
	_scroll_informacoes_offset = clamp(offset, 0.0, _scroll_informacoes_max)
	texto_informacoes.position.y = _texto_informacoes_y_base - _scroll_informacoes_offset


# IMPORTANTE: no Inspector, "Mouse > Filter" de PainelInformacoes precisa
# ser "Stop" (ou "Pass"), senão o Godot ignora o evento de roda do mouse por
# padrão (mesma observação já feita para os slots em _conectar_um_slot).
func _on_painel_informacoes_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_aplicar_scroll_informacoes(_scroll_informacoes_offset + VELOCIDADE_SCROLL_INFORMACOES)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_aplicar_scroll_informacoes(_scroll_informacoes_offset - VELOCIDADE_SCROLL_INFORMACOES)


# Monta o conteúdo completo do PainelInformacoes para o desafio informado:
# título "INFORMAÇÕES ÚTEIS", explicação do conceito, estrutura genérica do
# laço, o papel de cada parte, uma dica de raciocínio, o objetivo geral e,
# por fim, a instrução específica deste desafio (INSTRUCAO_FOR/WHILE), que
# continua aparecendo junto. Nunca revela a ordem ou o conteúdo exato dos
# blocos corretos — só o CONCEITO por trás do laço.
func _montar_texto_informacoes(desafio: String) -> String:
	var explicacao: String
	var estrutura: String
	var pontos: Array[String]
	var dica: String
	var objetivo: String
	var instrucao: String

	if desafio == "FOR":
		explicacao = INFO_FOR_EXPLICACAO
		estrutura = INFO_FOR_ESTRUTURA
		pontos = INFO_FOR_PONTOS
		dica = INFO_FOR_DICA
		objetivo = INFO_FOR_OBJETIVO
		instrucao = INSTRUCAO_FOR
	else:
		explicacao = INFO_WHILE_EXPLICACAO
		estrutura = INFO_WHILE_ESTRUTURA
		pontos = INFO_WHILE_PONTOS
		dica = INFO_WHILE_DICA
		objetivo = INFO_WHILE_OBJETIVO
		instrucao = INSTRUCAO_WHILE

	var linhas := PackedStringArray()
	linhas.append(explicacao)
	linhas.append("")
	linhas.append("Estrutura básica:")
	linhas.append("")
	linhas.append(estrutura)
	linhas.append("")
	for ponto in pontos:
		linhas.append("• %s" % ponto)
	linhas.append("")
	linhas.append("DICA:")
	linhas.append(dica)
	linhas.append("")
	linhas.append("Objetivo:")
	linhas.append(objetivo)
	linhas.append("")
	linhas.append("Desafio atual:")
	linhas.append(instrucao)

	return "\n".join(linhas)


# Percorre toda a árvore aplicando texto branco sem contorno a qualquer
# Label ou RichTextLabel encontrado (Titulo, PainelInformacoes, TextoFeedback,
# e quaisquer outros Labels já existentes na cena).
func _aplicar_estilo_textos_recursivo(no: Node) -> void:
	if no is Label:
		no.add_theme_color_override("font_color", COR_TEXTO)
		no.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0))
		no.add_theme_constant_override("outline_size", 0)
	elif no is RichTextLabel:
		no.add_theme_color_override("default_color", COR_TEXTO)
		no.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0))
		no.add_theme_constant_override("outline_size", 0)

	for filho in no.get_children():
		_aplicar_estilo_textos_recursivo(filho)


# Aplica borda vermelha (COR_BORDA) aos painéis principais, preservando o
# restante do estilo (fundo, corner_radius) que já existir em cada um.
func _aplicar_bordas_paineis() -> void:
	for painel in [janela_puzzle, painel_informacoes, painel_for, painel_while, painel_opcoes, painel_botoes]:
		_aplicar_borda_painel(painel)


func _aplicar_borda_painel(painel: Control) -> void:
	var estilo_atual: StyleBox = painel.get_theme_stylebox("panel")
	var estilo: StyleBoxFlat

	if estilo_atual is StyleBoxFlat:
		estilo = estilo_atual.duplicate()
	else:
		estilo = StyleBoxFlat.new()
		# Antes ficava totalmente transparente; agora ganha um fundo escuro
		# sutil para que cada painel pareça uma seção delimitada da
		# fortaleza, sem competir com a borda vermelha.
		estilo.bg_color = COR_PAINEL_FUNDO
		estilo.set_corner_radius_all(RAIO_CANTO_PAINEL)

	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(LARGURA_BORDA_PAINEL)
	painel.add_theme_stylebox_override("panel", estilo)


func _aplicar_estilo_botao(botao: BaseButton) -> void:
	# O BaseButton troca automaticamente de StyleBox conforme o estado
	# (normal / hover / pressed / disabled) — vale tanto para as opções do
	# PainelOpcoes quanto para os slots (que também são Buttons), sem exigir
	# sinais extras e sem alterar posição, tamanho ou escala.
	botao.add_theme_stylebox_override("normal", _criar_estilo_normal())
	botao.add_theme_stylebox_override("hover", _criar_estilo_hover())
	botao.add_theme_stylebox_override("pressed", _criar_estilo_pressed())
	botao.add_theme_stylebox_override("disabled", _criar_estilo_disabled())
	_aplicar_cores_texto_botao(botao)


# Cores de texto compartilhadas por qualquer botão/slot do puzzle (extraído
# de _aplicar_estilo_botao para ser reaproveitado pelos novos estilos de
# opção/slot/ações, sem duplicar as mesmas 6 linhas em cada um).
func _aplicar_cores_texto_botao(botao: BaseButton) -> void:
	botao.add_theme_color_override("font_color", COR_TEXTO)
	botao.add_theme_color_override("font_hover_color", COR_TEXTO)
	botao.add_theme_color_override("font_pressed_color", COR_TEXTO)
	botao.add_theme_color_override("font_focus_color", COR_TEXTO)
	botao.add_theme_color_override("font_disabled_color", COR_TEXTO)
	botao.add_theme_constant_override("outline_size", 0)


func _criar_estilo_normal() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_BOTAO_FUNDO
	estilo.border_color = COR_BOTAO_BORDA_NORMAL
	estilo.set_border_width_all(BORDA_LARGURA_NORMAL)
	estilo.set_corner_radius_all(RAIO_CANTO_BOTAO)
	return estilo


func _criar_estilo_hover() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_BOTAO_FUNDO
	estilo.border_color = COR_BOTAO_BORDA_HOVER
	estilo.set_border_width_all(BORDA_LARGURA_HOVER)
	estilo.set_corner_radius_all(RAIO_CANTO_BOTAO)
	return estilo


func _criar_estilo_pressed() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_BOTAO_FUNDO_PRESSED
	estilo.border_color = COR_BOTAO_BORDA_PRESSED
	estilo.set_border_width_all(BORDA_LARGURA_HOVER)
	estilo.set_corner_radius_all(RAIO_CANTO_BOTAO)
	return estilo


func _criar_estilo_disabled() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_BOTAO_FUNDO_DISABLED
	estilo.border_color = COR_BOTAO_BORDA_DISABLED
	estilo.set_border_width_all(BORDA_LARGURA_NORMAL)
	estilo.set_corner_radius_all(RAIO_CANTO_BOTAO)
	return estilo


# ---------------------------------------------------------------------------
# PAINELOPCOES — visual de "bloco/runa": canto mais arredondado e leve
# sombra, para não parecer igual aos slots. Cores e lógica de hover/pressed/
# disabled continuam as mesmas (COR_BOTAO_*).
# ---------------------------------------------------------------------------
func _aplicar_estilo_opcao(botao: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COR_BOTAO_FUNDO
	normal.border_color = COR_BOTAO_BORDA_NORMAL
	normal.set_border_width_all(BORDA_LARGURA_NORMAL)
	normal.set_corner_radius_all(RAIO_CANTO_OPCAO)
	normal.shadow_color = COR_SOMBRA_OPCAO
	normal.shadow_size = 3

	var hover := normal.duplicate()
	hover.border_color = COR_BOTAO_BORDA_HOVER
	hover.set_border_width_all(BORDA_LARGURA_HOVER)
	hover.shadow_size = 4

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COR_BOTAO_FUNDO_PRESSED
	pressed.border_color = COR_BOTAO_BORDA_PRESSED
	pressed.set_border_width_all(BORDA_LARGURA_HOVER)
	pressed.set_corner_radius_all(RAIO_CANTO_OPCAO)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = COR_BOTAO_FUNDO_DISABLED
	disabled.border_color = COR_BOTAO_BORDA_DISABLED
	disabled.set_border_width_all(BORDA_LARGURA_NORMAL)
	disabled.set_corner_radius_all(RAIO_CANTO_OPCAO)

	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressed)
	botao.add_theme_stylebox_override("disabled", disabled)
	_aplicar_cores_texto_botao(botao)


# ---------------------------------------------------------------------------
# SLOTS — visual de "encaixe": vazio (discreto, com ___) vs preenchido
# (destaque dourado). Chamado a cada troca de estado do slot; não muda em
# nada a lógica de qual botão vai para qual slot.
# ---------------------------------------------------------------------------
func _criar_estilo_slot(cor_fundo: Color, cor_borda: Color, largura_borda: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor_fundo
	estilo.border_color = cor_borda
	estilo.set_border_width_all(largura_borda)
	estilo.set_corner_radius_all(4)
	return estilo


func _aplicar_estilo_slot_vazio(slot: BaseButton) -> void:
	slot.add_theme_stylebox_override("normal", _criar_estilo_slot(COR_SLOT_VAZIO_FUNDO, COR_SLOT_VAZIO_BORDA, BORDA_LARGURA_NORMAL))
	slot.add_theme_stylebox_override("hover", _criar_estilo_slot(COR_SLOT_VAZIO_FUNDO, COR_BORDA, BORDA_LARGURA_HOVER))
	slot.add_theme_stylebox_override("pressed", _criar_estilo_slot(COR_BOTAO_FUNDO_PRESSED, COR_BOTAO_BORDA_PRESSED, BORDA_LARGURA_HOVER))
	slot.add_theme_stylebox_override("disabled", _criar_estilo_slot(COR_BOTAO_FUNDO_DISABLED, COR_BOTAO_BORDA_DISABLED, BORDA_LARGURA_NORMAL))
	_aplicar_cores_texto_botao(slot)


func _aplicar_estilo_slot_preenchido(slot: BaseButton) -> void:
	slot.add_theme_stylebox_override("normal", _criar_estilo_slot(COR_SLOT_PREENCHIDO_FUNDO, COR_SLOT_PREENCHIDO_BORDA, BORDA_LARGURA_HOVER))
	slot.add_theme_stylebox_override("hover", _criar_estilo_slot(COR_SLOT_PREENCHIDO_FUNDO, COR_DOURADO_CLARO, BORDA_LARGURA_HOVER))
	slot.add_theme_stylebox_override("pressed", _criar_estilo_slot(COR_BOTAO_FUNDO_PRESSED, COR_BOTAO_BORDA_PRESSED, BORDA_LARGURA_HOVER))
	slot.add_theme_stylebox_override("disabled", _criar_estilo_slot(COR_BOTAO_FUNDO_DISABLED, COR_BOTAO_BORDA_DISABLED, BORDA_LARGURA_NORMAL))
	_aplicar_cores_texto_botao(slot)


# ---------------------------------------------------------------------------
# HIERARQUIA DOS BOTÕES DE AÇÃO — Executar em destaque (dourado/primário),
# Limpar discreto (secundário). Testar mantém _aplicar_estilo_botao (o
# estilo padrão já existente).
# ---------------------------------------------------------------------------
func _aplicar_estilo_botao_executar(botao: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COR_EXECUTAR_FUNDO
	normal.border_color = COR_EXECUTAR_BORDA
	normal.set_border_width_all(BORDA_LARGURA_EXECUTAR)
	normal.set_corner_radius_all(RAIO_CANTO_BOTAO)

	var hover := normal.duplicate()
	hover.border_color = COR_EXECUTAR_BORDA_HOVER
	hover.set_border_width_all(BORDA_LARGURA_EXECUTAR + 1)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COR_EXECUTAR_FUNDO_PRESSED
	pressed.border_color = COR_EXECUTAR_BORDA_HOVER
	pressed.set_border_width_all(BORDA_LARGURA_EXECUTAR)
	pressed.set_corner_radius_all(RAIO_CANTO_BOTAO)

	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressed)
	botao.add_theme_stylebox_override("disabled", _criar_estilo_disabled())
	_aplicar_cores_texto_botao(botao)


func _aplicar_estilo_botao_limpar(botao: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COR_LIMPAR_FUNDO
	normal.border_color = COR_LIMPAR_BORDA
	normal.set_border_width_all(BORDA_LARGURA_NORMAL)
	normal.set_corner_radius_all(RAIO_CANTO_BOTAO)

	var hover := normal.duplicate()
	hover.border_color = COR_LIMPAR_BORDA_HOVER

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COR_LIMPAR_FUNDO_PRESSED
	pressed.border_color = COR_LIMPAR_BORDA_HOVER
	pressed.set_border_width_all(BORDA_LARGURA_NORMAL)
	pressed.set_corner_radius_all(RAIO_CANTO_BOTAO)

	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressed)
	botao.add_theme_stylebox_override("disabled", _criar_estilo_disabled())
	_aplicar_cores_texto_botao(botao)


# ---------------------------------------------------------------------------
# TEXTEDIT (declaração de variável) — visual de terminal/editor de código:
# fundo escuro, borda discreta (dourada em foco), fonte monoespaçada
# (SystemFont, sem precisar importar nenhum arquivo de fonte novo) e
# padding interno. Não transforma o TextEdit em Button nem altera cursor/
# seleção — só aparência.
# ---------------------------------------------------------------------------
func _aplicar_estilo_textedit() -> void:
	var fonte_mono := SystemFont.new()
	fonte_mono.font_names = ["Consolas", "Courier New", "monospace"]

	for textedit in [texto_var_for, texto_var_while]:
		if textedit == null:
			continue

		var normal := StyleBoxFlat.new()
		normal.bg_color = COR_TEXTEDIT_FUNDO
		normal.border_color = COR_TEXTEDIT_BORDA
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(4)
		normal.content_margin_left = PADDING_TEXTEDIT
		normal.content_margin_right = PADDING_TEXTEDIT
		normal.content_margin_top = PADDING_TEXTEDIT * 0.6
		normal.content_margin_bottom = PADDING_TEXTEDIT * 0.6

		var foco := normal.duplicate()
		foco.border_color = COR_TEXTEDIT_BORDA_FOCO

		textedit.add_theme_stylebox_override("normal", normal)
		textedit.add_theme_stylebox_override("focus", foco)
		textedit.add_theme_stylebox_override("read_only", normal)

		textedit.add_theme_color_override("font_color", COR_TEXTO)
		textedit.add_theme_color_override("background_color", COR_TEXTEDIT_FUNDO)
		textedit.add_theme_color_override("caret_color", COR_DOURADO)
		textedit.add_theme_color_override("font_selected_color", COR_TEXTO)
		textedit.add_theme_color_override("selection_color", Color(COR_DOURADO.r, COR_DOURADO.g, COR_DOURADO.b, 0.35))

		textedit.add_theme_font_override("font", fonte_mono)


# ---------------------------------------------------------------------------
# SCROLLFEEDBACK (VScrollBar, opcional) — combina com o tema vermelho/dourado.
# ---------------------------------------------------------------------------
func _aplicar_estilo_scrollbar_feedback() -> void:
	if scroll_feedback == null:
		return

	var trilho := StyleBoxFlat.new()
	trilho.bg_color = COR_TEXTEDIT_FUNDO
	trilho.set_corner_radius_all(4)

	var alca := StyleBoxFlat.new()
	alca.bg_color = COR_BOTAO_BORDA_NORMAL
	alca.set_corner_radius_all(4)

	var alca_hover := StyleBoxFlat.new()
	alca_hover.bg_color = COR_DOURADO
	alca_hover.set_corner_radius_all(4)

	var alca_pressed := StyleBoxFlat.new()
	alca_pressed.bg_color = COR_DOURADO_CLARO
	alca_pressed.set_corner_radius_all(4)

	scroll_feedback.add_theme_stylebox_override("scroll", trilho)
	scroll_feedback.add_theme_stylebox_override("grabber", alca)
	scroll_feedback.add_theme_stylebox_override("grabber_highlight", alca_hover)
	scroll_feedback.add_theme_stylebox_override("grabber_pressed", alca_pressed)


# ---------------------------------------------------------------------------
# CONEXÃO DE SINAIS
# ---------------------------------------------------------------------------
func _conectar_opcoes() -> void:
	for opcao in painel_opcoes.get_children():
		if opcao is BaseButton:
			opcao.pressed.connect(_on_opcao_pressionada.bind(opcao))


func _conectar_slots() -> void:
	for slot in _slots_for.values():
		_conectar_um_slot(slot, "FOR")
	for slot in _slots_while.values():
		_conectar_um_slot(slot, "WHILE")


func _conectar_um_slot(slot: Node, desafio: String) -> void:
	if slot is BaseButton:
		slot.pressed.connect(_on_slot_pressionado.bind(slot, desafio))
	elif slot is Control:
		# IMPORTANTE: no Inspector, "Mouse > Filter" precisa ser "Stop" (ou
		# "Pass") nesses Nodes, senão o Godot ignora o clique por padrão.
		slot.gui_input.connect(_on_slot_gui_input.bind(slot, desafio))


func _on_slot_gui_input(event: InputEvent, slot: Node, desafio: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_pressionado(slot, desafio)


func _conectar_botoes() -> void:
	btn_executar.pressed.connect(_on_executar_pressed)
	btn_limpar.pressed.connect(_on_limpar_pressed)
	btn_testar.pressed.connect(_on_testar_pressed)


# ---------------------------------------------------------------------------
# DESAFIO ATIVO
# ---------------------------------------------------------------------------
# Troca o desafio ativo e atualiza Titulo/PainelInformacoes, sem apagar
# progresso de nenhum dos dois desafios.
func _mudar_desafio_ativo(desafio: String) -> void:
	_desafio_ativo = desafio
	if desafio == "FOR":
		_set_texto(titulo, INSTRUCAO_FOR)
	else:
		_set_texto(titulo, INSTRUCAO_WHILE)
	_set_texto(texto_informacoes, _montar_texto_informacoes(desafio))
	_aplicar_scroll_informacoes(0.0)


# ---------------------------------------------------------------------------
# COLOCAR OPÇÃO NO PRIMEIRO SLOT VAZIO (qualquer opção, certa ou errada)
# ---------------------------------------------------------------------------
func _on_opcao_pressionada(opcao: Node) -> void:
	var nome_slot: String = _primeiro_slot_vazio(_desafio_ativo)

	if nome_slot == "":
		# Todos os slots do desafio ativo já estão ocupados: não substitui,
		# não apaga nada, simplesmente ignora o clique.
		return

	var slot_node: Node = _pegar_slot(_desafio_ativo, nome_slot)
	var estado: Dictionary = _pegar_estado(_desafio_ativo)

	# Identificação interna (usada na validação) continua sendo o nome do
	# Node — nunca o texto visível.
	estado[nome_slot] = opcao.name
	_opcao_no_slot["%s:%s" % [_desafio_ativo, nome_slot]] = opcao

	# O slot mostra o TEXTO VISÍVEL do botão (opcao.text), não o nome
	# interno do Node (opcao.name).
	_set_texto(slot_node, opcao.text)
	if slot_node is BaseButton:
		_aplicar_estilo_slot_preenchido(slot_node)
	opcao.visible = false
	opcao.disabled = true


func _primeiro_slot_vazio(desafio: String) -> String:
	var estado: Dictionary = _pegar_estado(desafio)
	for nome_slot in _ordem_slots(desafio):
		if estado.get(nome_slot, "") == "":
			return nome_slot
	return ""


func _ordem_slots(desafio: String) -> Array:
	return ORDEM_SLOTS_FOR if desafio == "FOR" else ORDEM_SLOTS_WHILE


# ---------------------------------------------------------------------------
# REMOVER OPÇÃO DE UM SLOT (somente aquele slot, somente no desafio ativo)
# ---------------------------------------------------------------------------
func _on_slot_pressionado(slot_node: Node, desafio: String) -> void:
	if desafio != _desafio_ativo:
		return
	if _esta_resolvido(desafio):
		return  # desafio já concluído: não pode remover blocos dele

	var nome_slot: String = _nome_do_slot(desafio, slot_node)
	if nome_slot == "":
		return

	var estado: Dictionary = _pegar_estado(desafio)
	if estado.get(nome_slot, "") == "":
		return  # slot vazio -> clicar não faz nada

	var chave: String = "%s:%s" % [desafio, nome_slot]
	var opcao: Node = _opcao_no_slot.get(chave, null)

	estado[nome_slot] = ""
	_set_texto(slot_node, PLACEHOLDER)
	if slot_node is BaseButton:
		_aplicar_estilo_slot_vazio(slot_node)

	if opcao != null:
		opcao.visible = true
		opcao.disabled = false
		_opcao_no_slot.erase(chave)


# ---------------------------------------------------------------------------
# HELPERS DE ESTADO
# ---------------------------------------------------------------------------
func _nome_do_slot(desafio: String, slot_node: Node) -> String:
	var slots: Dictionary = _pegar_slots(desafio)
	for nome in slots.keys():
		if slots[nome] == slot_node:
			return nome
	return ""


func _pegar_slots(desafio: String) -> Dictionary:
	return _slots_for if desafio == "FOR" else _slots_while


func _pegar_estado(desafio: String) -> Dictionary:
	return _estado_for if desafio == "FOR" else _estado_while


func _pegar_slot(desafio: String, nome_slot: String) -> Node:
	return _pegar_slots(desafio)[nome_slot]


func _esta_resolvido(desafio: String) -> bool:
	return _for_resolvido if desafio == "FOR" else _while_resolvido


# Define texto em qualquer Node que tenha a propriedade "text"
# (Label, RichTextLabel, Button, etc.) sem quebrar se o Node for nulo.
func _set_texto(no: Node, texto: String) -> void:
	if no != null and "text" in no:
		no.text = texto


func _atualizar_visual_todos_slots() -> void:
	for nome in _slots_for.keys():
		_set_texto(_slots_for[nome], PLACEHOLDER)
		if _slots_for[nome] is BaseButton:
			_aplicar_estilo_slot_vazio(_slots_for[nome])
	for nome in _slots_while.keys():
		_set_texto(_slots_while[nome], PLACEHOLDER)
		if _slots_while[nome] is BaseButton:
			_aplicar_estilo_slot_vazio(_slots_while[nome])


# ---------------------------------------------------------------------------
# LIMPAR (apenas o desafio ativo; nunca desfaz um desafio já concluído)
# ---------------------------------------------------------------------------
func _on_limpar_pressed() -> void:
	var desafio := _desafio_ativo
	var linhas := PackedStringArray()
	linhas.append("> Limpando desafio %s..." % desafio)
	linhas.append("")

	if _esta_resolvido(desafio):
		linhas.append("[!] O desafio %s já foi concluído e não pode ser limpo." % desafio)
		_mostrar_saida(linhas)
		return

	var slots := _pegar_slots(desafio)
	var estado := _pegar_estado(desafio)

	for nome_slot in slots.keys():
		var chave: String = "%s:%s" % [desafio, nome_slot]
		var opcao: Node = _opcao_no_slot.get(chave, null)
		if opcao != null:
			opcao.visible = true
			opcao.disabled = false
			_opcao_no_slot.erase(chave)
		estado[nome_slot] = ""
		_set_texto(slots[nome_slot], PLACEHOLDER)
		if slots[nome_slot] is BaseButton:
			_aplicar_estilo_slot_vazio(slots[nome_slot])

	linhas.append("[OK] Desafio %s limpo." % desafio)
	linhas.append("[INFO] Os blocos foram devolvidos ao PainelOpcoes.")
	_mostrar_saida(linhas)


# ---------------------------------------------------------------------------
# VALIDAÇÃO (compartilhada por Testar e Executar — nunca usa eval)
# ---------------------------------------------------------------------------
# Retorna "vazio", "incorreto" ou "correto" com base no estado ATUAL dos
# slots do desafio informado (não depende de _for_resolvido/_while_resolvido).
# Compara sempre por nome de Node (opcao.name), nunca pelo texto visível.
# A declaração de variável do TextEdit é obrigatória: TextEdit vazio conta
# como "vazio" (mesmo com slots preenchidos), e TextEdit com conteúdo
# diferente do esperado conta como "incorreto" (mesmo com slots corretos).
func _validar(desafio: String) -> String:
	var estado := _pegar_estado(desafio)
	var resposta := RESPOSTA_FOR if desafio == "FOR" else RESPOSTA_WHILE
	var texto_var := _pegar_texto_variavel(desafio).strip_edges()
	var resposta_var := RESPOSTA_VAR_FOR if desafio == "FOR" else RESPOSTA_VAR_WHILE

	if texto_var == "":
		return "vazio"

	for chave in resposta.keys():
		if estado.get(chave, "") == "":
			return "vazio"

	if texto_var != resposta_var:
		return "incorreto"

	for chave in resposta.keys():
		if estado.get(chave, "") != resposta[chave]:
			return "incorreto"

	return "correto"


# Retorna o texto atual do TextEdit de declaração de variável do desafio
# informado (PainelFOR/TextEdit ou PainelWhile/TextEdit).
func _pegar_texto_variavel(desafio: String) -> String:
	return texto_var_for.text if desafio == "FOR" else texto_var_while.text


# ---------------------------------------------------------------------------
# SIMULAÇÃO DE SAÍDA (nunca executa loop de verdade — apenas representa)
# ---------------------------------------------------------------------------
func _simular_for() -> PackedStringArray:
	var linhas := PackedStringArray()
	for i in range(1, 11):
		linhas.append("> %d" % i)
	return linhas


# Representa visualmente uma sequência infinita, de forma limitada e segura
# (nunca roda um while real) — mostra o início, "...", um trecho mais à
# frente e "..." de novo, para passar a ideia de continuidade indefinida.
func _simular_while() -> PackedStringArray:
	var linhas := PackedStringArray()
	for i in range(1, 7):
		linhas.append("> %d" % i)
	linhas.append("> ...")
	for i in range(20, 23):
		linhas.append("> %d" % i)
	linhas.append("> ...")
	return linhas


# ---------------------------------------------------------------------------
# TESTAR — verifica, simula e avança o desafio ativo; NUNCA finaliza
# ---------------------------------------------------------------------------
func _on_testar_pressed() -> void:
	# Guarda o estado ANTES de reconhecer progresso, para saber se um
	# desafio acabou de ser resolvido justamente por causa deste clique
	# (e assim decidir qual mensagem mostrar).
	var for_ja_resolvido_antes: bool = _for_resolvido
	var while_ja_resolvido_antes: bool = _while_resolvido
	var desafio_testado: String = _desafio_ativo

	_reconhecer_progresso()

	var linhas := PackedStringArray()

	if _for_resolvido and _while_resolvido:
		# Ambos já corretos (agora ou antes deste clique).
		linhas.append("> Testando todos os desafios...")
		linhas.append("")
		linhas.append("[OK] Desafio FOR concluído!")
		linhas.append("[OK] Desafio WHILE concluído!")
		linhas.append("")
		linhas.append("[OK] Todos os desafios estão corretos!")
		linhas.append("")
		linhas.append("INFO: clique em Executar para confirmar a finalização do puzzle.")

	elif desafio_testado == "FOR":
		linhas.append("> Testando desafio FOR...")
		linhas.append("")
		if _for_resolvido and not for_ja_resolvido_antes:
			linhas.append("[OK] Desafio FOR concluído!")
			linhas.append("")
			linhas.append("Saída:")
			linhas.append_array(_simular_for())
			linhas.append("")
			linhas.append("[!] Próximo desafio: WHILE.")
		else:
			match _validar("FOR"):
				"vazio":
					linhas.append("[!] Existem slots vazios.")
					linhas.append("[!] Preencha todos os slots antes de testar.")
				"incorreto":
					linhas.append("[X] O desafio FOR está incorreto.")
					linhas.append("[!] Revise os blocos e tente novamente.")

	else:
		# desafio_testado == "WHILE" (FOR já estava resolvido antes deste clique)
		linhas.append("> Testando desafio WHILE...")
		linhas.append("")
		if _while_resolvido and not while_ja_resolvido_antes:
			linhas.append("[OK] Estrutura WHILE correta!")
			linhas.append("")
			linhas.append("Saída simulada:")
			linhas.append_array(_simular_while())
			linhas.append("")
			linhas.append("INFO: a execução foi interrompida apenas para fins de demonstração.")
		else:
			match _validar("WHILE"):
				"vazio":
					linhas.append("[!] Existem slots vazios.")
					linhas.append("[!] Preencha todos os slots antes de testar.")
				"incorreto":
					linhas.append("[X] O desafio WHILE está incorreto.")
					linhas.append("[!] Revise os blocos e tente novamente.")

	_mostrar_saida(linhas)


# ---------------------------------------------------------------------------
# EXECUTAR — confirma o desafio ativo, avança FOR -> WHILE e finaliza
# ---------------------------------------------------------------------------
func _on_executar_pressed() -> void:
	_reconhecer_progresso()

	# Confirmação final: só acontece quando os dois já estão corretos.
	if _for_resolvido and _while_resolvido:
		if not _puzzle_resolvido:
			_puzzle_resolvido = true

			var linhas := PackedStringArray()
			linhas.append("> Executando puzzle...")
			linhas.append("")
			linhas.append("[OK] Desafio FOR concluído!")
			linhas.append("[OK] Desafio WHILE concluído!")
			linhas.append("")
			linhas.append("[OK] PUZZLE CONCLUÍDO!")
			linhas.append("")
			linhas.append("INFO: todos os desafios foram resolvidos com sucesso.")
			_mostrar_saida(linhas)

			desafio_concluido.emit()
		return

	# Ainda falta algo: não finaliza, só mostra o que está pendente.
	var linhas := PackedStringArray()
	if not _for_resolvido:
		linhas.append("> Executando desafio FOR...")
		linhas.append("")
		match _validar("FOR"):
			"vazio":
				linhas.append("[!] Existem slots vazios.")
				linhas.append("[!] Preencha todos os slots do desafio FOR antes de executar.")
			"incorreto":
				linhas.append("[X] O desafio FOR está incorreto.")
				linhas.append("[!] Revise os blocos e tente novamente.")
	elif not _while_resolvido:
		linhas.append("> Executando desafio WHILE...")
		linhas.append("")
		match _validar("WHILE"):
			"vazio":
				linhas.append("[!] Existem slots vazios.")
				linhas.append("[!] Preencha todos os slots do desafio WHILE antes de executar.")
			"incorreto":
				linhas.append("[X] O desafio WHILE está incorreto.")
				linhas.append("[!] Revise os blocos e tente novamente.")

	_mostrar_saida(linhas)


# Reconhece FOR/WHILE como concluídos assim que o estado atual dos slots
# bate com a resposta esperada, preservando o progresso e avançando
# automaticamente o desafio ativo de FOR para WHILE. Compartilhado por
# Testar e Executar para que os dois se comportem de forma consistente.
func _reconhecer_progresso() -> void:
	if not _for_resolvido and _validar("FOR") == "correto":
		_for_resolvido = true
		if _desafio_ativo == "FOR":
			_mudar_desafio_ativo("WHILE")

	if not _while_resolvido and _validar("WHILE") == "correto":
		_while_resolvido = true
