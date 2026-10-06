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

# Quando true, _validar() imprime no Output do Godot qual slot/campo não
# bateu (esperado x recebido). Útil para diagnosticar por que um desafio não
# fica "correto". Pode ser colocado em false depois que tudo estiver ok.
const DEBUG_VALIDACAO := true

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO — RESPOSTAS CORRETAS
# ---------------------------------------------------------------------------
# Chaves = nome INTERNO do slot (usado em ORDEM_SLOTS_*, RESPOSTA_* e no
# dicionário de estado) — não precisa bater com o nome real do Node na cena.
# Valores = nome do Node (opcao.name) esperado nesse slot — NÃO o texto
# visível. A validação compara sempre por nome de nó (ignorando maiúsculas/
# minúsculas e "(" solto no início — ver _normalizar_nome).
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
#
# CORREÇÃO: o valor de "Console_log(runa)" estava "(console_log(runa)"
# (parêntese sobrando no início e "c" minúsculo), o que fazia a validação do
# WHILE nunca ficar "correto". Agora segue o mesmo padrão do FOR.
const RESPOSTA_WHILE := {
	"SlotWhile": "WHILE",
	"Condicao": "runa > 0",
	"Console_log(runa)": "Console_log(runa)",
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
# ESTÉTICA — PALETA (PRETO + VERMELHO ARCANO + BRANCO)
# ---------------------------------------------------------------------------
# Mesma linguagem visual do Puzzle da Cidade Celestial (fundo preto, painéis
# escuros, bordas coloridas, hover parcial, glow discreto, estados distintos),
# mas com identidade própria: vermelho arcano. O vermelho aparece em bordas,
# destaques, hover, focus e títulos; as grandes áreas continuam pretas/escuras.
#
# Hierarquia dos vermelhos (do mais escuro/discreto ao mais intenso):
#   MUITO_ESCURO -> elementos secundários (fundo do botão Limpar)
#   ESCURO       -> fundo do hover parcial
#   APAGADO      -> slot vazio, estados desabilitados, moldura do feedback
#   FORTE        -> fundo do estado pressed
#   MEDIO        -> bordas de painéis, hover secundário
#   (base)       -> borda padrão de botões e blocos
#   INTENSO      -> focus
#   VIVO         -> destaques importantes (título, slot preenchido, Executar)
#   BRILHO       -> hover/texto de destaque (o mais claro)
const COR_FUNDO := Color("000000")            # fundo geral
const COR_PAINEL := Color("0c0607")           # painéis (quase preto, leve traço vermelho)
const COR_BOTAO := Color("110708")            # fundo dos botões/blocos
const COR_TERMINAL := Color("070304")         # TextEdit, feedback e trilho da scrollbar

const COR_VERMELHO_MUITO_ESCURO := Color("1c0709")
const COR_VERMELHO_ESCURO := Color("330b10")
const COR_VERMELHO_APAGADO := Color("6b2c32")
const COR_VERMELHO_FORTE := Color("7d1119")
const COR_VERMELHO_MEDIO := Color("a3202b")
const COR_VERMELHO := Color("d42b37")         # vermelho base (bordas de botões/blocos)
const COR_VERMELHO_INTENSO := Color("f0323f")
const COR_VERMELHO_VIVO := Color("ff4655")
const COR_VERMELHO_BRILHO := Color("ff9098")

const COR_TEXTO := Color("f5efef")            # branco levemente quente
const COR_TEXTO_DESABILITADO := Color("84666a")

const RAIO_BORDA := 6
const RAIO_OPCAO := 8                         # blocos de PainelOpcoes: um pouco mais "runa"
const RAIO_TERMINAL := 4

# Alfa do glow (sombra vermelha sem deslocamento) — discreto.
const ALFA_BRILHO := 0.35

# Margens internas dos botões/slots (mantidas pequenas para não crescer os
# botões além do tamanho definido na cena). Se algum botão ficar maior que o
# original, reduza estes dois valores.
const MARGEM_H_BOTAO := 6
const MARGEM_V_BOTAO := 4

# TextEdit (declaração de variável): visual de terminal/editor de código.
const PADDING_TEXTEDIT := 10

# Margem interna do texto do TextoFeedback dentro da moldura desenhada por
# _desenhar_moldura_feedback (não altera posição nem tamanho do nó).
const MARGEM_FEEDBACK_H := 8
const MARGEM_FEEDBACK_V := 4

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
# Retângulo original do TextoFeedback (capturado uma vez), usado para desenhar
# a moldura fixa do "terminal" atrás do texto, mesmo enquanto ele rola.
var _rect_moldura_feedback := Rect2()


# Fundo geral preto. Desenhado pelo próprio Control raiz (fica atrás dos
# filhos), então não precisa de nenhum nó novo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)


func _aplicar_estetica_puzzle() -> void:
	# Redesenha o fundo preto quando a cena for redimensionada.
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

	# Texto claro sem contorno em todos os Labels; títulos sobrescrevem depois.
	_aplicar_estilo_textos_recursivo(self)

	# Painéis: janela preta, painéis quase pretos, bordas vermelhas + glow leve.
	_aplicar_bordas_paineis()
	# FOR e WHILE: o desafio ativo ganha destaque (vermelho vivo + glow).
	_atualizar_destaque_desafios()

	# Títulos: BarraTitulo/Titulo (destaque) e TituloInformacoes (secundário).
	_estilizar_titulo(titulo.get_parent() as Control, true)
	_colorir_label_titulo(titulo, COR_VERMELHO_BRILHO, true)
	_estilizar_titulo(titulo_informacoes, false)

	# PainelOpcoes: blocos/runa.
	for opcao in painel_opcoes.get_children():
		if opcao is Button:
			_aplicar_estilo_opcao(opcao)

	# Slots: começam todos vazios; o estilo vazio/preenchido é atualizado
	# depois, quando o jogador coloca ou remove um bloco (ver
	# _on_opcao_pressionada/_on_slot_pressionado/_on_limpar_pressed/
	# _atualizar_visual_todos_slots).
	for slot in _slots_for.values():
		if slot is BaseButton:
			_aplicar_estilo_slot_vazio(slot)
	for slot in _slots_while.values():
		if slot is BaseButton:
			_aplicar_estilo_slot_vazio(slot)

	# Botões de ação: Executar em destaque, Testar padrão, Limpar discreto.
	_estilizar_botao_padrao(btn_testar)
	_estilizar_botao_executar(btn_executar)
	_estilizar_botao_limpar(btn_limpar)

	_aplicar_estilo_textedit()
	_aplicar_estilo_scrollbar_feedback()
	_configurar_moldura_feedback()


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


# Percorre toda a árvore aplicando texto claro sem contorno a qualquer Label
# ou RichTextLabel encontrado (Titulo, PainelInformacoes, TextoFeedback e
# quaisquer outros Labels já existentes na cena). Títulos sobrescrevem depois.
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


# ---------------------------------------------------------------------------
# BLOCOS BÁSICOS DE ESTILO (mesma ideia do Puzzle da Cidade Celestial)
# ---------------------------------------------------------------------------
# Cria um StyleBoxFlat.
# - largura: espessura da borda em todos os lados;
# - brilho: tamanho do glow vermelho (sombra sem deslocamento); 0 = sem brilho;
# - largura_esq / largura_baixo: espessura extra só nesses lados (faixa parcial
#   usada no hover); -1 mantém a largura padrão;
# - margem_h / margem_v: margens internas (>= 0 para fixar; -1 usa o padrão);
# - raio: canto arredondado.
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
		sb.shadow_color = Color(COR_VERMELHO_VIVO.r, COR_VERMELHO_VIVO.g, COR_VERMELHO_VIVO.b, ALFA_BRILHO)
		sb.shadow_size = brilho
		sb.shadow_offset = Vector2.ZERO
	if margem_h >= 0:
		sb.content_margin_left = margem_h
		sb.content_margin_right = margem_h
	if margem_v >= 0:
		sb.content_margin_top = margem_v
		sb.content_margin_bottom = margem_v
	return sb


# Contorno de foco: só a borda, sem preencher o botão.
func _caixa_foco(raio: int = RAIO_BORDA) -> StyleBoxFlat:
	var sb := _caixa(Color(0, 0, 0, 0), COR_VERMELHO_INTENSO, 2, 0, -1, -1, -1, -1, raio)
	sb.draw_center = false
	return sb


# Aplica os estilos de cada estado e as cores de texto a um Button.
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
# PAINÉIS
# ---------------------------------------------------------------------------
# Janela preta; demais painéis quase pretos; todos com borda vermelha média e
# glow leve. PainelFOR/PainelWhile são estilizados em
# _atualizar_destaque_desafios (para destacar o desafio ativo).
func _aplicar_bordas_paineis() -> void:
	_aplicar_borda_painel(janela_puzzle, COR_FUNDO, COR_VERMELHO_MEDIO, 3, 0)
	for painel in [painel_informacoes, painel_opcoes, painel_botoes]:
		_aplicar_borda_painel(painel, COR_PAINEL, COR_VERMELHO_MEDIO, 2, 6)


func _aplicar_borda_painel(painel: Control, fundo: Color, borda: Color, largura: int, brilho: int) -> void:
	if painel == null:
		return
	painel.add_theme_stylebox_override("panel", _caixa(fundo, borda, largura, brilho))


# Destaque dos desafios: o painel do desafio ATIVO fica com borda vermelho vivo
# e glow; o outro volta para a borda média discreta. Só aparência — chamado
# por _mudar_desafio_ativo e na aplicação inicial da estética.
func _atualizar_destaque_desafios() -> void:
	_estilizar_painel_desafio(painel_for, _desafio_ativo == "FOR")
	_estilizar_painel_desafio(painel_while, _desafio_ativo == "WHILE")


func _estilizar_painel_desafio(painel: Control, ativo: bool) -> void:
	if painel == null:
		return
	if ativo:
		_aplicar_borda_painel(painel, COR_PAINEL, COR_VERMELHO_VIVO, 2, 8)
	else:
		_aplicar_borda_painel(painel, COR_PAINEL, COR_VERMELHO_MEDIO, 2, 0)


# ---------------------------------------------------------------------------
# TÍTULOS — fundo preto, borda vermelha arredondada, texto claro.
# O título principal ganha borda mais grossa/viva, glow e texto vermelho-claro.
# Funciona se o nó for um Label ou uma área (Panel/PanelContainer) com Label
# dentro; áreas não recebem margens extras para não deslocar o conteúdo.
# ---------------------------------------------------------------------------
func _estilizar_titulo(no: Control, destaque: bool = false) -> void:
	if no == null:
		return

	var borda := COR_VERMELHO_VIVO if destaque else COR_VERMELHO
	var largura := 3 if destaque else 2
	var brilho := 12 if destaque else 0
	var cor_texto := COR_VERMELHO_BRILHO if destaque else COR_TEXTO

	if no is Label:
		no.add_theme_stylebox_override("normal", _caixa(COR_FUNDO, borda, largura, brilho, -1, -1, 8, 2))
		_colorir_label_titulo(no as Label, cor_texto, destaque)
	else:
		no.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, borda, largura, brilho))
		for filho in no.find_children("*", "Label", true, false):
			_colorir_label_titulo(filho as Label, cor_texto, destaque)


func _colorir_label_titulo(label: Label, cor_texto: Color, destaque: bool) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", cor_texto)
	if destaque:
		label.add_theme_color_override("font_outline_color", COR_VERMELHO_FORTE)
		label.add_theme_constant_override("outline_size", 2)


# ---------------------------------------------------------------------------
# BOTÕES
# ---------------------------------------------------------------------------
# Botão padrão (Testar). Hover PARCIAL: continua escuro, mas ganha borda mais
# clara, faixa mais grossa à esquerda e embaixo e um tom vermelho bem escuro
# no fundo. Pressed é diferente do hover; disabled é bem apagado.
func _estilizar_botao_padrao(botao: Button, raio: int = RAIO_BORDA) -> void:
	var normal := _caixa(COR_BOTAO, COR_VERMELHO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 2, 8, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(raio), disabled, COR_TEXTO)


# PainelOpcoes — visual de "bloco/runa": mesmo padrão dos botões, com canto um
# pouco mais arredondado para não parecer igual aos slots.
func _aplicar_estilo_opcao(botao: BaseButton) -> void:
	if botao is Button:
		_estilizar_botao_padrao(botao as Button, RAIO_OPCAO)


# Executar (ação primária): borda vermelho vivo mais grossa e glow constante.
func _estilizar_botao_executar(botao: Button) -> void:
	var normal := _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_VIVO, 3, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 3, 12, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


# Limpar (ação secundária): mais discreto, sem glow.
func _estilizar_botao_limpar(botao: Button) -> void:
	var normal := _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_APAGADO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_MEDIO, 2, 0, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


# ---------------------------------------------------------------------------
# SLOTS — visual de "encaixe".
# Slot vazio: preto, borda vermelha apagada e fina/discreta.
# Slot preenchido: preto, borda vermelha grossa com glow e texto vermelho-claro;
# o hover do slot preenchido usa o mesmo destaque parcial dos botões.
# Chamados a cada troca de estado do slot; não mudam em nada a lógica de qual
# botão vai para qual slot.
# ---------------------------------------------------------------------------
func _aplicar_estilo_slot_vazio(slot: BaseButton) -> void:
	if not (slot is Button):
		return
	var normal := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_FUNDO, COR_VERMELHO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot as Button, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)


func _aplicar_estilo_slot_preenchido(slot: BaseButton) -> void:
	if not (slot is Button):
		return
	var normal := _caixa(COR_FUNDO, COR_VERMELHO, 3, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 3, 10, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot as Button, normal, hover, pressed, _caixa_foco(), normal, COR_VERMELHO_BRILHO)


# ---------------------------------------------------------------------------
# TEXTEDIT (declaração de variável) — visual de terminal/editor de código:
# fundo quase preto, borda vermelha (viva + glow em foco), fonte
# monoespaçada (SystemFont, sem importar nenhum arquivo de fonte novo) e
# padding interno. Não transforma o TextEdit em Button nem altera cursor/
# seleção — só aparência.
#
# --- ALTERAÇÃO APLICADA AQUI: borda normal ficou mais visível ---
# Antes: COR_VERMELHO_APAGADO, 2px, sem glow (quase imperceptível).
# Agora: COR_VERMELHO, 3px, glow leve (4) no estado normal; o foco manteve
# COR_VERMELHO_VIVO, mas com borda/glow um pouco mais fortes (3px, glow 10)
# para continuar se destacando claramente do estado normal.
# Nenhuma outra propriedade (fundo, fonte, padding, cursor, seleção,
# current_line) foi alterada.
# ---------------------------------------------------------------------------
func _aplicar_estilo_textedit() -> void:
	var fonte_mono := SystemFont.new()
	fonte_mono.font_names = ["Consolas", "Courier New", "monospace"]

	var margem_v: int = int(PADDING_TEXTEDIT * 0.6)

	for textedit in [texto_var_for, texto_var_while]:
		if textedit == null:
			continue

		# --- ALTERAÇÃO: borda normal mais forte/visível ---
		var normal := _caixa(COR_TERMINAL, COR_VERMELHO, 3, 4, -1, -1, PADDING_TEXTEDIT, margem_v, RAIO_TERMINAL)
		# --- ALTERAÇÃO: foco com borda/glow um pouco mais intensos ---
		var foco := _caixa(COR_TERMINAL, COR_VERMELHO_VIVO, 3, 10, -1, -1, PADDING_TEXTEDIT, margem_v, RAIO_TERMINAL)

		textedit.add_theme_stylebox_override("normal", normal)
		textedit.add_theme_stylebox_override("focus", foco)
		textedit.add_theme_stylebox_override("read_only", normal)

		textedit.add_theme_color_override("font_color", COR_TEXTO)
		textedit.add_theme_color_override("background_color", COR_TERMINAL)
		textedit.add_theme_color_override("caret_color", COR_VERMELHO_BRILHO)
		textedit.add_theme_color_override("font_selected_color", COR_TEXTO)
		textedit.add_theme_color_override("selection_color", Color(COR_VERMELHO.r, COR_VERMELHO.g, COR_VERMELHO.b, 0.35))
		textedit.add_theme_color_override("current_line_color", Color(COR_VERMELHO.r, COR_VERMELHO.g, COR_VERMELHO.b, 0.08))

		textedit.add_theme_font_override("font", fonte_mono)


# ---------------------------------------------------------------------------
# TEXTOFEEDBACK — moldura de "terminal"
# ---------------------------------------------------------------------------
# TextoFeedback é um Label solto dentro de JanelaPuzzle (sem painel próprio).
# Para dar a ele uma caixa visual sem criar nenhum Node e sem mexer em posição
# ou tamanho:
#   1) o retângulo original do Label é guardado uma única vez;
#   2) JanelaPuzzle desenha uma moldura escura com borda vermelha apagada nesse
#      retângulo (fica atrás do texto, fixa mesmo enquanto o texto rola);
#   3) o texto ganha uma margem interna via StyleBoxEmpty (só afasta o texto da
#      borda; não desenha nada).
func _configurar_moldura_feedback() -> void:
	if texto_feedback == null or janela_puzzle == null:
		return

	_rect_moldura_feedback = Rect2(texto_feedback.position, texto_feedback.size)

	var margem := StyleBoxEmpty.new()
	margem.content_margin_left = MARGEM_FEEDBACK_H
	margem.content_margin_right = MARGEM_FEEDBACK_H
	margem.content_margin_top = MARGEM_FEEDBACK_V
	margem.content_margin_bottom = MARGEM_FEEDBACK_V
	texto_feedback.add_theme_stylebox_override("normal", margem)

	if not janela_puzzle.draw.is_connected(_desenhar_moldura_feedback):
		janela_puzzle.draw.connect(_desenhar_moldura_feedback)
	janela_puzzle.queue_redraw()


func _desenhar_moldura_feedback() -> void:
	if _rect_moldura_feedback.size.x <= 0.0 or _rect_moldura_feedback.size.y <= 0.0:
		return
	var moldura := _caixa(COR_TERMINAL, COR_VERMELHO_APAGADO, 2, 0, -1, -1, -1, -1, RAIO_TERMINAL)
	janela_puzzle.draw_style_box(moldura, _rect_moldura_feedback)


# ---------------------------------------------------------------------------
# SCROLLFEEDBACK (VScrollBar, opcional) — combina com o tema vermelho/preto.
# ---------------------------------------------------------------------------
func _aplicar_estilo_scrollbar_feedback() -> void:
	if scroll_feedback == null:
		return

	var trilho := StyleBoxFlat.new()
	trilho.bg_color = COR_TERMINAL
	trilho.set_corner_radius_all(RAIO_TERMINAL)

	var alca := StyleBoxFlat.new()
	alca.bg_color = COR_VERMELHO_FORTE
	alca.set_corner_radius_all(RAIO_TERMINAL)

	var alca_hover := StyleBoxFlat.new()
	alca_hover.bg_color = COR_VERMELHO
	alca_hover.set_corner_radius_all(RAIO_TERMINAL)

	var alca_pressed := StyleBoxFlat.new()
	alca_pressed.bg_color = COR_VERMELHO_VIVO
	alca_pressed.set_corner_radius_all(RAIO_TERMINAL)

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


# Conecta Executar/Limpar/Testar. Cada conexão é protegida por is_connected:
# se o sinal "pressed" já tiver sido ligado pelo editor (aba Node > Signals)
# à mesma função, conectar de novo por código geraria erro de conexão
# duplicada — e, dependendo do caso, o handler poderia rodar duas vezes.
func _conectar_botoes() -> void:
	if not btn_executar.pressed.is_connected(_on_executar_pressed):
		btn_executar.pressed.connect(_on_executar_pressed)
	if not btn_limpar.pressed.is_connected(_on_limpar_pressed):
		btn_limpar.pressed.connect(_on_limpar_pressed)
	if not btn_testar.pressed.is_connected(_on_testar_pressed):
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
	_atualizar_destaque_desafios()  # só aparência: destaca o painel do desafio ativo


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
# Compara sempre por nome de Node (opcao.name), nunca pelo texto visível —
# usando _normalizar_nome() para não depender de maiúsculas/minúsculas nem de
# um "(" solto no início do nome.
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

	var tudo_correto := true

	if texto_var != resposta_var:
		tudo_correto = false
		if DEBUG_VALIDACAO:
			print("[Puzzle_Fortaleza][%s] TextEdit: esperado '%s', recebido '%s'" % [desafio, resposta_var, texto_var])

	for chave in resposta.keys():
		var recebido: String = str(estado.get(chave, ""))
		var esperado: String = str(resposta[chave])
		if _normalizar_nome(recebido) != _normalizar_nome(esperado):
			tudo_correto = false
			if DEBUG_VALIDACAO:
				print("[Puzzle_Fortaleza][%s] slot '%s': esperado (Node.name) '%s', recebido '%s'" % [desafio, chave, esperado, recebido])

	return "correto" if tudo_correto else "incorreto"


# Normaliza um nome de Node para comparação: sem espaços nas pontas, tudo
# minúsculo e sem "(" sobrando no início. Só afrouxa diferenças de digitação
# — blocos realmente diferentes continuam sendo diferentes.
func _normalizar_nome(nome: Variant) -> String:
	return str(nome).strip_edges().to_lower().lstrip("(")


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
	# _puzzle_resolvido garante que o sinal seja emitido uma única vez.
	if _for_resolvido and _while_resolvido:
		if not _puzzle_resolvido:
			_puzzle_resolvido = true

			var linhas_final := PackedStringArray()
			linhas_final.append("> Executando puzzle...")
			linhas_final.append("")
			linhas_final.append("[OK] Desafio FOR concluído!")
			linhas_final.append("[OK] Desafio WHILE concluído!")
			linhas_final.append("")
			linhas_final.append("[OK] PUZZLE CONCLUÍDO!")
			linhas_final.append("")
			linhas_final.append("INFO: todos os desafios foram resolvidos com sucesso.")
			_mostrar_saida(linhas_final)

			# O puzzle NÃO troca de fase: só avisa. Quem escuta este sinal
			# (PC -> puzzle_concluido(fase_id) -> GameManager) decide o resto.
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
