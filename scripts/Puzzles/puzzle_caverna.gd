extends Control

# ==================================================================
# Puzzle_IfElse
# Fase 2 - Caverna de Cristal | Tema: IF / ELSE em JavaScript
# Script principal do puzzle. Fica diretamente no nó raiz Puzzle_IfElse.
# NÃO cria nós nem altera a árvore da cena — apenas controla o
# comportamento e a aparência (via theme overrides/propriedades) dos
# nós já existentes.
#
# ATUALIZAÇÃO 1: CampoCondicao, AcaoIF e AcaoELSE deixaram de ser
# LineEdit e passaram a ser Button, funcionando com a MESMA mecânica de
# slots que já existia para SlotIF/SlotELSE (preenchidos por cliques no
# PainelOpcoes, nunca digitados).
#
# Os nós do PainelOpcoes que preenchem esses três slots foram
# RENOMEADOS diretamente na cena:
#   OpcaoFALSE      -> "Opcao(cristal > 10)"          -> preenche CampoCondicao
#   OpcaoTRUE       -> "Opcaoconsole_log(_Maior_)"     -> preenche AcaoIF
#   OpcaoIgualIgual -> "Opcaoconsole_log(_Menor_)"     -> preenche AcaoELSE
# Como esses nomes contêm parênteses e espaço, os caminhos $... abaixo
# usam a sintaxe de string entre aspas ($"Caminho/Com Espaço").
#
# ATUALIZAÇÃO 2: TextoFeedback agora mostra mensagens específicas por
# tipo de erro (declaração, IF, condição, ação do IF, ELSE, ação do
# ELSE) e sucesso, permite múltiplas linhas e nunca corta o texto (ver
# seção 11). O nó em si NÃO foi recriado — apenas configurado.
#
# ATUALIZAÇÃO 3: Sistema de "desfazer individual" por slot. Cada um dos
# 5 slots (SlotIF, CampoCondicao, AcaoIF, SlotELSE, AcaoELSE) agora
# lembra qual botão do PainelOpcoes originou seu conteúdo. Clicar em um
# slot JÁ OCUPADO devolve apenas aquela opção ao PainelOpcoes (visível e
# habilitada novamente) e esvazia somente aquele slot — sem afetar os
# outros quatro. Clicar em um slot VAZIO continua sem fazer nada. O
# botão "Limpar" continua reiniciando tudo de uma vez (ver seção 11).
#
# ATUALIZAÇÃO 4: Estilização visual totalmente refeita (seção 14),
# usando como referência a linguagem visual do Puzzle_cidade (a mesma
# fase do jogo), mas trocando a identidade azul pela identidade roxa da
# Caverna de Cristal. Os slots agora também têm aparência diferente
# quando vazios e quando preenchidos, exatamente como no Puzzle_cidade
# — por isso pequenas chamadas de atualização visual foram adicionadas
# nas seções 7 e 11, sem alterar nenhuma lógica funcional.
# ==================================================================


# ==================================================================
# 1. SINAIS
# ==================================================================

## Emitido quando o jogador resolve o puzzle corretamente.
## O script pc.gd já espera por este sinal para liberar o disquete/fase.
## O puzzle NUNCA troca de fase diretamente: ele só emite o sinal.
## Fluxo: Puzzle_IfElse -> desafio_concluido -> PC -> puzzle_concluido(fase_id) -> GameManager.
signal desafio_concluido


# ==================================================================
# 2. REFERÊNCIAS DOS NÓS
# ==================================================================

@onready var _janela_puzzle: Panel = $JanelaPuzzle
@onready var _barra_titulo: Panel = $JanelaPuzzle/BarraTitulo
@onready var _botao_fechar: TextureButton = $JanelaPuzzle/BarraTitulo/BotaoFechar

@onready var _label_desafio: Label = $JanelaPuzzle/Desafio

# Campos e slots da área de código (PainelCodigo continua sendo um Panel).
# CampoDeclaracao continua sendo digitado pelo teclado (LineEdit).
# CampoCondicao, AcaoIF e AcaoELSE agora são Button e funcionam como
# slots, exatamente como SlotIF/SlotELSE — o jogador nunca digita neles.
@onready var _painel_codigo: Panel = $JanelaPuzzle/PainelCodigo
@onready var _campo_declaracao: LineEdit = $JanelaPuzzle/PainelCodigo/CampoDeclaracao
@onready var _slot_if: Button = $JanelaPuzzle/PainelCodigo/SlotIF
@onready var _campo_condicao: Button = $JanelaPuzzle/PainelCodigo/CampoCondicao
@onready var _acao_if: Button = $JanelaPuzzle/PainelCodigo/AcaoIF
@onready var _slot_else: Button = $JanelaPuzzle/PainelCodigo/SlotELSE
@onready var _acao_else: Button = $JanelaPuzzle/PainelCodigo/AcaoELSE
# DoisPontosIF e DoisPontosELSE são Labels visuais que representam a
# ABERTURA de bloco em JavaScript ("{"), não os dois-pontos de Python (":").
# O script referencia e força esse texto em _configurar_sintaxe_javascript()
# para garantir que o puzzle nunca pareça Python, mesmo que o texto tenha
# sido deixado como ":" no editor da cena.
@onready var _dois_pontos_if: Label = $JanelaPuzzle/PainelCodigo/DoisPontosIF
@onready var _dois_pontos_else: Label = $JanelaPuzzle/PainelCodigo/DoisPontosELSE

@onready var _painel_dicas: Panel = $JanelaPuzzle/PainelDicas
@onready var _texto_dicas: RichTextLabel = $JanelaPuzzle/PainelDicas/TextoDicas

# Botões de opções (PainelOpcoes é um Control, sem GridOpcoes).
# _opcao_condicao, _opcao_console_maior e _opcao_console_menor apontam
# para os nós RENOMEADOS na cena (ver cabeçalho do arquivo). Os caminhos
# usam aspas porque os novos nomes contêm parênteses e espaço, o que
# exige a sintaxe $"caminho/com espaço" em vez de $caminho/sem_aspas.
@onready var _painel_opcoes: Control = $JanelaPuzzle/PainelOpcoes
@onready var _opcao_if: Button = $JanelaPuzzle/PainelOpcoes/OpcaoIF
@onready var _opcao_else: Button = $JanelaPuzzle/PainelOpcoes/OpcaoELSE
@onready var _opcao_elif: Button = $JanelaPuzzle/PainelOpcoes/OpcaoELIF
@onready var _opcao_while: Button = $JanelaPuzzle/PainelOpcoes/OpcaoWHILE
@onready var _opcao_condicao: Button = $"JanelaPuzzle/PainelOpcoes/Opcao(cristal > 10)"
@onready var _opcao_console_maior: Button = $"JanelaPuzzle/PainelOpcoes/Opcaoconsole_log(_Maior_)"
@onready var _opcao_console_menor: Button = $"JanelaPuzzle/PainelOpcoes/Opcaoconsole_log(_Menor_)"
@onready var _opcao_igual: Button = $JanelaPuzzle/PainelOpcoes/OpcaoIgual
@onready var _opcao_maior: Button = $JanelaPuzzle/PainelOpcoes/OpcaoMaior
@onready var _opcao_menor: Button = $JanelaPuzzle/PainelOpcoes/OpcaoMenor
@onready var _opcao_diferente: Button = $JanelaPuzzle/PainelOpcoes/OpcaoDiferente

@onready var _botao_executar: Button = $JanelaPuzzle/BotaoExecutar
@onready var _botao_limpar: Button = $JanelaPuzzle/Limpar

# TextoFeedback é o nó existente reaproveitado para todas as mensagens de
# resultado (sucesso/erro). Nunca é recriado — apenas configurado em
# _configurar_texto_feedback() (seção 11) e atualizado por
# _mostrar_feedback(), o único ponto do script que escreve nele.
@onready var _texto_feedback: Label = $JanelaPuzzle/PainelFeedback/TextoFeedback
@onready var _painel_feedback: Panel = $JanelaPuzzle/PainelFeedback


# ==================================================================
# 3. CONFIGURAÇÃO DO PUZZLE
# ==================================================================

## Texto do desafio apresentado ao jogador.
const TEXTO_DESAFIO: String = "Monte em JavaScript: declare a variável 'cristal', \
verifique com if/else se ela é maior que 10 e exiba a mensagem correspondente com console.log()."

## Estruturas esperadas para os slots (if / else).
## Continuam sendo a resposta CORRETA — mas qualquer opção disponível
## pode ser colocada em qualquer slot. A comparação com estes valores só
## é feita na hora de VALIDAR (seção 10), nunca na hora de preencher.
const ESTRUTURA_IF_ESPERADA: String = "if"
const ESTRUTURA_ELSE_ESPERADA: String = "else"

## Nome de variável exigido pela lógica do puzzle. O NÚMERO atribuído à
## variável continua livre (ver seção 10, VALIDAÇÃO).
const NOME_VARIAVEL_ESPERADO: String = "cristal"
## Mantido apenas como referência do valor de comparação da condição —
## o valor "vivo" usado na validação é o texto completo em
## TEXTO_CONDICAO_CORRETA logo abaixo, já que CampoCondicao agora é
## preenchido por um botão com texto fixo, não mais digitado.
const VALOR_COMPARACAO_ESPERADO: String = "10"

## Textos EXATOS que os três slots-botão (CampoCondicao, AcaoIF,
## AcaoELSE) precisam conter para o puzzle ser considerado correto.
## São também os textos inseridos por Opcao(cristal > 10),
## Opcaoconsole_log(_Maior_) e Opcaoconsole_log(_Menor_) (ver seção 7).
const TEXTO_CONDICAO_CORRETA: String = "(cristal > 10)"
const TEXTO_ACAO_IF_CORRETA: String = "console.log(\"Maior\");"
const TEXTO_ACAO_ELSE_CORRETA: String = "console.log(\"Menor\");"

## Mensagens exibidas em TextoFeedback (seção 10/11). Cada uma
## corresponde a exatamente um tipo de erro (ou ao sucesso), para que o
## jogador saiba precisamente o que corrigir. Mensagens com duas linhas
## usam "\n" — o TextoFeedback foi configurado para quebrar linha e
## nunca cortar o texto (ver _configurar_texto_feedback em seção 11).
const MSG_SUCESSO: String = "✓ Código correto! Desafio concluído!"
const MSG_ERRO_DECLARACAO: String = "✗ A declaração da variável está incorreta.\nUse: let cristal = número;"
const MSG_ERRO_IF: String = "✗ A estrutura IF está incorreta."
const MSG_ERRO_CONDICAO: String = "✗ A condição está incorreta.\nUse: (cristal > 10)"
const MSG_ERRO_ACAO_IF: String = "✗ A ação do IF está incorreta.\nUse: console.log(\"Maior\");"
const MSG_ERRO_ELSE: String = "✗ A estrutura ELSE está incorreta."
const MSG_ERRO_ACAO_ELSE: String = "✗ A ação do ELSE está incorreta.\nUse: console.log(\"Menor\");"
const MSG_CAMPOS_INCOMPLETOS: String = "⚠️ Preencha todos os campos antes de executar."
const MSG_ESPACOS_CHEIOS: String = "⚠️ Todos os espaços já estão preenchidos. Use Limpar para reiniciar."
const MSG_USE_LIMPAR: String = "Use o botão Limpar para reiniciar sua resposta."

## Dicas mostradas ao jogador. Fáceis de editar sem mexer na lógica.
## Cada dica é um par [título em negrito, texto], coloridos em _configurar_dicas().
## O texto final é BBCode e é exibido por um RichTextLabel com
## bbcode_enabled = true (ver _configurar_dicas) — por isso as tags
## [color]/[b] nunca aparecem literalmente na tela.
const DICAS: Array[Array] = [
	["Dica 1:", "if é usado quando queremos verificar uma condição."],
	["Dica 2:", "A condição vai entre parênteses, como em (cristal > 10)."],
	["Dica 3:", "else representa o caso em que a condição do if não foi satisfeita."],
	["Operadores:", "= é o operador de ATRIBUIÇÃO — guarda um valor em uma variável. Ex: cristal = 15. Não serve para comparar."],
	["", "> significa MAIOR QUE. Ex: cristal > 10 é verdadeiro se cristal for maior que 10. É o operador que este desafio pede."],
	["", "< significa MENOR QUE. Ex: cristal < 10 é verdadeiro se cristal for menor que 10."],
	["", "!= significa DIFERENTE DE. Ex: cristal != 10 é verdadeiro se cristal NÃO for igual a 10."],
	["console.log():", "é o comando usado em JavaScript para exibir uma mensagem no console (uma espécie de 'print')."],
	["", "Serve para mostrar textos, avisos ou o valor de variáveis durante a execução do código, ajudando a entender o que está acontecendo."],
	["", "No painel de opções você já encontra prontos os blocos console.log(\"Maior\"); e console.log(\"Menor\");, prontos para colocar no slot certo."],
	["Dica final:", "Em JavaScript, cada linha de comando termina com ';' e mensagens usam console.log(\"...\")."],
]

## Cores usadas no feedback (ajuste conforme a identidade visual do jogo).
## Mantidas independentes do roxo — comunicam erro/sucesso/alerta com
## clareza, exatamente como pedido.
const COR_FEEDBACK_ERRO: Color = Color(0.85, 0.25, 0.25)
const COR_FEEDBACK_SUCESSO: Color = Color(0.25, 0.75, 0.35)
const COR_FEEDBACK_ALERTA: Color = Color(0.85, 0.65, 0.15)

## ------------------------------------------------------------------
## Paleta visual do tema "Caverna de Cristal" (PRETO + ROXO + BRANCO/LILÁS).
## Segue a MESMA hierarquia de cores usada no Puzzle_cidade (que usa azul),
## trocando o azul por roxo. As áreas grandes continuam pretas/quase
## pretas; o roxo aparece em bordas, títulos, destaques, hover, focus,
## pressed e slots — nunca preenchendo a tela inteira.
## ------------------------------------------------------------------

const COR_FUNDO: Color = Color("#000000")           # preto — fundo geral
const COR_PAINEL: Color = Color("#0A0712")          # preto/roxo muito escuro — fundo dos painéis
const COR_BOTAO: Color = Color("#0D0A14")           # quase preto — fundo normal dos botões
const COR_ROXO: Color = Color("#B388FF")            # roxo-claro principal (bordas)
const COR_ROXO_BRILHO: Color = Color("#E5D4FF")     # roxo mais brilhante (hover/focus)
const COR_ROXO_APAGADO: Color = Color("#5A3F7A")    # roxo discreto (slot vazio / disabled)
const COR_ROXO_ESCURO: Color = Color("#1C0F2E")     # tom escuro para o hover parcial
const COR_ROXO_FORTE: Color = Color("#6A3FA0")      # roxo mais forte (pressed)
const COR_TEXTO: Color = Color("#F5EEFF")           # branco/lilás claro — texto principal
const COR_TEXTO_DESABILITADO: Color = Color("#6F5F85")

const RAIO_BORDA: int = 6

## Nomes mantidos por compatibilidade com o restante do script (dicas,
## bordas dos painéis etc.) — agora apontam para a nova paleta roxa.
const COR_TEXTO_CODIGO: Color = Color("#E5D4FF")
const COR_BORDA_PAINEL: Color = Color("#B388FF")
const ESPESSURA_BORDA_PAINEL: int = 2

## Cores do texto na área de dicas: título em negrito e o restante do texto.
const COR_DICA_DESTAQUE: String = "#C9A8F0"
const COR_DICA_TEXTO: String = "#E8DFF5"


# ==================================================================
# 4. ESTADO ATUAL
# ==================================================================

## Valor atualmente contido em cada um dos 5 "slots" ("" = vazio). Pode
## conter QUALQUER opção disponível — certa ou errada. A checagem de
## correção só acontece em _validar_puzzle() (seção 10).
var _valor_slot_if: String = ""
var _valor_campo_condicao: String = ""
var _valor_acao_if: String = ""
var _valor_slot_else: String = ""
var _valor_acao_else: String = ""

## NOVO (ATUALIZAÇÃO 3): guarda qual botão do PainelOpcoes originou o
## conteúdo de cada slot (null = slot vazio). É o que permite devolver
## exatamente a opção certa quando o jogador clica em um slot ocupado,
## em vez de só saber o TEXTO que está lá.
var _botao_origem_slot_if: Button = null
var _botao_origem_campo_condicao: Button = null
var _botao_origem_acao_if: Button = null
var _botao_origem_slot_else: Button = null
var _botao_origem_acao_else: Button = null

## Impede que o sinal desafio_concluido seja emitido mais de uma vez.
var _puzzle_resolvido: bool = false

## StyleBox usado para desenhar a borda roxa do PainelOpcoes (ele é um
## Control puro, sem stylebox de "panel" próprio — por isso é desenhado
## manualmente em _draw(), sem criar nenhum nó novo).
var _estilo_borda_opcoes: StyleBoxFlat = null

## Expressão regular usada na validação estrutural de CampoDeclaracao
## (compilada uma única vez em _ready). CampoCondicao, AcaoIF e AcaoELSE
## não usam mais regex: agora só podem conter texto fixo vindo dos
## botões do PainelOpcoes, então são comparados diretamente com as
## constantes TEXTO_CONDICAO_CORRETA / TEXTO_ACAO_IF_CORRETA /
## TEXTO_ACAO_ELSE_CORRETA (ver seção 10). Nunca é usada para executar
## código, apenas para reconhecer o formato do que o jogador digitou.
var _regex_declaracao: RegEx = null


# ==================================================================
# 5. _READY
# ==================================================================

func _ready() -> void:
	_compilar_expressoes_regulares()
	_configurar_desafio()
	_configurar_sintaxe_javascript()
	_configurar_botoes_opcoes()
	_configurar_botoes_slots()
	_configurar_botao_executar()
	_configurar_botao_limpar()
	_configurar_botao_fechar()
	_configurar_dicas()
	_configurar_texto_feedback()
	_aplicar_estilo_visual()
	_preparar_borda_painel_opcoes()
	_reiniciar_estado_puzzle()


func _compilar_expressoes_regulares() -> void:
	# let cristal = <qualquer número inteiro, com ou sem sinal>;
	# O ';' final é OBRIGATÓRIO — não é um '?' opcional no regex.
	# Usa-se \s* (e não \s+) porque _normalizar_texto() já remove TODOS os
	# espaços do texto digitado antes da comparação (ver seção 8), então o
	# regex compara contra algo como "letcristal=23;" — exigir \s+ aqui
	# rejeitaria até respostas corretas.
	_regex_declaracao = RegEx.new()
	_regex_declaracao.compile("^let\\s*%s\\s*=\\s*-?\\d+\\s*;$" % NOME_VARIAVEL_ESPERADO)


# ==================================================================
# 6. CONFIGURAÇÃO DOS BOTÕES
# ==================================================================

## Conecta um botão de forma segura: se o nó estiver null (caminho errado
## na cena — ex: nome não renomeado corretamente), avisa no console em
## vez de travar a configuração dos outros botões. Além disso, remove
## QUALQUER conexão anterior do sinal "pressed" (inclusive conexões
## feitas manualmente pelo editor, na aba Signals) antes de conectar a
## nova — isso evita que uma função antiga continue disparando junto com
## a lógica atual.
func _conectar_botao(botao: BaseButton, callable: Callable, nome_referencia: String) -> void:
	if botao == null:
		push_error("Puzzle_IfElse: o nó '%s' não foi encontrado. Confira se o nome no editor da cena corresponde exatamente." % nome_referencia)
		return

	for conexao: Dictionary in botao.pressed.get_connections():
		var callable_existente: Callable = conexao["callable"]
		if callable_existente != callable:
			botao.pressed.disconnect(callable_existente)

	if not botao.pressed.is_connected(callable):
		botao.pressed.connect(callable)


## TODAS as 11 opções (if, else, elif, while, (cristal > 10),
## console.log("Maior");, console.log("Menor");, =, >, <, !=) vão
## SOMENTE para os 5 slots, sempre o primeiro vazio, na ordem:
## SlotIF -> CampoCondicao -> AcaoIF -> SlotELSE -> AcaoELSE.
## Nenhuma opção interage com CampoDeclaracao — ele continua sendo um
## LineEdit comum, preenchido apenas pelo teclado.
## Não existe lógica de "somente certas opções podem ser usadas" nem de
## opções "distratoras" bloqueadas: todas as 11 preenchem algum slot,
## certas ou erradas. A validação de certo/errado só acontece ao clicar
## em "Executar" (seção 10).
func _configurar_botoes_opcoes() -> void:
	_conectar_botao(_opcao_if, _on_opcao_if_pressionada, "PainelOpcoes/OpcaoIF")
	_conectar_botao(_opcao_else, _on_opcao_else_pressionada, "PainelOpcoes/OpcaoELSE")
	_conectar_botao(_opcao_elif, _on_opcao_elif_pressionada, "PainelOpcoes/OpcaoELIF")
	_conectar_botao(_opcao_while, _on_opcao_while_pressionada, "PainelOpcoes/OpcaoWHILE")
	_conectar_botao(_opcao_condicao, _on_opcao_condicao_pressionada, "PainelOpcoes/Opcao(cristal > 10)")
	_conectar_botao(_opcao_console_maior, _on_opcao_console_maior_pressionada, "PainelOpcoes/Opcaoconsole_log(_Maior_)")
	_conectar_botao(_opcao_console_menor, _on_opcao_console_menor_pressionada, "PainelOpcoes/Opcaoconsole_log(_Menor_)")
	_conectar_botao(_opcao_igual, _on_opcao_igual_pressionada, "PainelOpcoes/OpcaoIgual")
	_conectar_botao(_opcao_maior, _on_opcao_maior_pressionada, "PainelOpcoes/OpcaoMaior")
	_conectar_botao(_opcao_menor, _on_opcao_menor_pressionada, "PainelOpcoes/OpcaoMenor")
	_conectar_botao(_opcao_diferente, _on_opcao_diferente_pressionada, "PainelOpcoes/OpcaoDiferente")


## Agora conecta os 5 botões-slot: SlotIF, CampoCondicao, AcaoIF,
## SlotELSE e AcaoELSE. Todos usam o mesmo padrão: se o slot estiver
## ocupado, o clique devolve a opção correspondente ao PainelOpcoes
## (ver seção 7); se estiver vazio, não faz nada.
func _configurar_botoes_slots() -> void:
	_conectar_botao(_slot_if, _on_slot_if_pressionado, "PainelCodigo/SlotIF")
	_conectar_botao(_campo_condicao, _on_campo_condicao_pressionado, "PainelCodigo/CampoCondicao")
	_conectar_botao(_acao_if, _on_acao_if_pressionado, "PainelCodigo/AcaoIF")
	_conectar_botao(_slot_else, _on_slot_else_pressionado, "PainelCodigo/SlotELSE")
	_conectar_botao(_acao_else, _on_acao_else_pressionado, "PainelCodigo/AcaoELSE")


func _configurar_botao_executar() -> void:
	_conectar_botao(_botao_executar, _on_botao_executar_pressed, "BotaoExecutar")


func _configurar_botao_limpar() -> void:
	_conectar_botao(_botao_limpar, _on_botao_limpar_pressed, "Limpar")


func _configurar_botao_fechar() -> void:
	_conectar_botao(_botao_fechar, _on_botao_fechar_pressed, "BarraTitulo/BotaoFechar")


# ==================================================================
# 7. SISTEMA DE SLOTS E OPÇÕES
# ==================================================================
# Cada opção usada some (visible = false) e, a partir da ATUALIZAÇÃO 3,
# pode voltar de DUAS formas:
#   1) clicando em "Limpar" — devolve as 5 opções usadas de uma vez
#      (comportamento original, ver seção 11);
#   2) clicando DIRETAMENTE no slot que a contém — devolve SOMENTE
#      aquela opção, sem mexer nos outros slots (novo comportamento).
#
# Para isso, cada slot guarda não só o TEXTO exibido (_valor_*), mas
# também o BOTÃO de origem (_botao_origem_*), preenchido em
# _preencher_proximo_slot_vazio() e usado por _remover_opcao_do_slot()
# para saber exatamente qual opção devolver ao PainelOpcoes.
#
# Existem 5 slots (SlotIF, CampoCondicao, AcaoIF, SlotELSE, AcaoELSE) e
# 11 opções. Depois dos 5 primeiros cliques os slots ficam cheios e
# qualquer opção clicada depois disso apenas mostra um aviso — sem
# alterar nada (a menos que o jogador libere um slot antes).
#
# ATUALIZAÇÃO 4 (visual): sempre que um slot é preenchido ou esvaziado,
# chamamos _atualizar_estilo_slot() (seção 14) para trocar sua
# aparência entre "vazio" e "preenchido", igual ao Puzzle_cidade. Isso
# não muda em nada QUANDO/COMO um slot é preenchido ou esvaziado —
# apenas redesenha o botão depois que a lógica já decidiu o que fazer.

## Preenche o primeiro slot vazio, na ordem SlotIF -> CampoCondicao ->
## AcaoIF -> SlotELSE -> AcaoELSE, com o texto informado, e guarda o
## botão de origem daquele slot para permitir o "desfazer individual".
## Retorna true se conseguiu preencher algum slot, ou false se os cinco
## já estavam ocupados (nesse caso nada é alterado). Esta função NUNCA
## escreve em CampoDeclaracao — só nos 5 slots-botão.
func _preencher_proximo_slot_vazio(texto: String, botao_origem: Button) -> bool:
	if _valor_slot_if == "":
		_valor_slot_if = texto
		_botao_origem_slot_if = botao_origem
		if _slot_if != null:
			_slot_if.text = texto
			_atualizar_estilo_slot(_slot_if, true)
		return true
	if _valor_campo_condicao == "":
		_valor_campo_condicao = texto
		_botao_origem_campo_condicao = botao_origem
		if _campo_condicao != null:
			_campo_condicao.text = texto
			_atualizar_estilo_slot(_campo_condicao, true)
		return true
	if _valor_acao_if == "":
		_valor_acao_if = texto
		_botao_origem_acao_if = botao_origem
		if _acao_if != null:
			_acao_if.text = texto
			_atualizar_estilo_slot(_acao_if, true)
		return true
	if _valor_slot_else == "":
		_valor_slot_else = texto
		_botao_origem_slot_else = botao_origem
		if _slot_else != null:
			_slot_else.text = texto
			_atualizar_estilo_slot(_slot_else, true)
		return true
	if _valor_acao_else == "":
		_valor_acao_else = texto
		_botao_origem_acao_else = botao_origem
		if _acao_else != null:
			_acao_else.text = texto
			_atualizar_estilo_slot(_acao_else, true)
		return true
	return false


## Usado por TODAS as opções (if/else/elif/while/condição/console.log/
## operadores). Só interage com os 5 slots — jamais com CampoDeclaracao.
func _usar_opcao(botao: Button, texto: String) -> void:
	var preenchido: bool = _preencher_proximo_slot_vazio(texto, botao)
	if not preenchido:
		_mostrar_feedback(MSG_ESPACOS_CHEIOS, COR_FEEDBACK_ALERTA)
		return
	if botao != null:
		botao.visible = false
		botao.disabled = true


func _on_opcao_if_pressionada() -> void:
	_usar_opcao(_opcao_if, "if")


func _on_opcao_else_pressionada() -> void:
	_usar_opcao(_opcao_else, "else")


func _on_opcao_elif_pressionada() -> void:
	_usar_opcao(_opcao_elif, "elif")


func _on_opcao_while_pressionada() -> void:
	_usar_opcao(_opcao_while, "while")


## Nó "Opcao(cristal > 10)" — insere a condição completa, que só é
## considerada correta se cair em CampoCondicao (posição 2 dos slots).
func _on_opcao_condicao_pressionada() -> void:
	_usar_opcao(_opcao_condicao, TEXTO_CONDICAO_CORRETA)


## Nó "Opcaoconsole_log(_Maior_)" — insere a ação do IF.
func _on_opcao_console_maior_pressionada() -> void:
	_usar_opcao(_opcao_console_maior, TEXTO_ACAO_IF_CORRETA)


## Nó "Opcaoconsole_log(_Menor_)" — insere a ação do ELSE.
func _on_opcao_console_menor_pressionada() -> void:
	_usar_opcao(_opcao_console_menor, TEXTO_ACAO_ELSE_CORRETA)


func _on_opcao_igual_pressionada() -> void:
	_usar_opcao(_opcao_igual, "=")


func _on_opcao_maior_pressionada() -> void:
	_usar_opcao(_opcao_maior, ">")


func _on_opcao_menor_pressionada() -> void:
	_usar_opcao(_opcao_menor, "<")


func _on_opcao_diferente_pressionada() -> void:
	_usar_opcao(_opcao_diferente, "!=")


## NOVO (ATUALIZAÇÃO 3): devolve a opção de origem de um slot ao
## PainelOpcoes (visível e habilitada de novo) e limpa apenas aquele
## slot (texto volta a "___", valor interno volta a "" e a referência ao
## botão de origem volta a null). Reaproveita o mesmo tipo de efeito
## colateral usado em _usar_opcao(), só que na direção inversa.
func _liberar_opcao_no_painel(botao_origem: Button) -> void:
	if botao_origem == null:
		return
	botao_origem.visible = true
	botao_origem.disabled = false


## Clicar em um slot já preenchido agora devolve SOMENTE aquela opção
## ao PainelOpcoes e esvazia SOMENTE aquele slot — os outros quatro
## permanecem intactos. Clicar em um slot vazio ("___") continua sem
## fazer nada. O botão "Limpar" continua sendo o único que reinicia
## TODOS os slots de uma vez (seção 11).
func _on_slot_if_pressionado() -> void:
	if _valor_slot_if == "":
		return
	_liberar_opcao_no_painel(_botao_origem_slot_if)
	_valor_slot_if = ""
	_botao_origem_slot_if = null
	if _slot_if != null:
		_slot_if.text = "___"
		_atualizar_estilo_slot(_slot_if, false)


func _on_campo_condicao_pressionado() -> void:
	if _valor_campo_condicao == "":
		return
	_liberar_opcao_no_painel(_botao_origem_campo_condicao)
	_valor_campo_condicao = ""
	_botao_origem_campo_condicao = null
	if _campo_condicao != null:
		_campo_condicao.text = "___"
		_atualizar_estilo_slot(_campo_condicao, false)


func _on_acao_if_pressionado() -> void:
	if _valor_acao_if == "":
		return
	_liberar_opcao_no_painel(_botao_origem_acao_if)
	_valor_acao_if = ""
	_botao_origem_acao_if = null
	if _acao_if != null:
		_acao_if.text = "___"
		_atualizar_estilo_slot(_acao_if, false)


func _on_slot_else_pressionado() -> void:
	if _valor_slot_else == "":
		return
	_liberar_opcao_no_painel(_botao_origem_slot_else)
	_valor_slot_else = ""
	_botao_origem_slot_else = null
	if _slot_else != null:
		_slot_else.text = "___"
		_atualizar_estilo_slot(_slot_else, false)


func _on_acao_else_pressionado() -> void:
	if _valor_acao_else == "":
		return
	_liberar_opcao_no_painel(_botao_origem_acao_else)
	_valor_acao_else = ""
	_botao_origem_acao_else = null
	if _acao_else != null:
		_acao_else.text = "___"
		_atualizar_estilo_slot(_acao_else, false)


# ==================================================================
# 8. SISTEMA DE CAMPOS
# ==================================================================

## CampoDeclaracao continua sendo o único campo digitado pelo jogador.
func _campo_declaracao_preenchido() -> bool:
	return not _campo_declaracao.text.strip_edges().is_empty()


## Agora verifica os 5 slots (SlotIF, CampoCondicao, AcaoIF, SlotELSE,
## AcaoELSE), todos preenchidos por clique nas opções do PainelOpcoes.
func _todos_slots_preenchidos() -> bool:
	return _valor_slot_if != "" \
		and _valor_campo_condicao != "" \
		and _valor_acao_if != "" \
		and _valor_slot_else != "" \
		and _valor_acao_else != ""


## Normaliza o texto para fins de COMPARAÇÃO interna, sem jamais alterar o
## texto exibido:
##   - remove espaços (inclusive múltiplos/nas pontas): "cristal > 10" e
##     "cristal>10" tornam-se equivalentes;
##   - converte para minúsculas: "LET CRISTAL", "Let Cristal" e
##     "let cristal" tornam-se equivalentes.
## Nunca executa o texto — apenas compara/reconhece o formato da string.
## Usada tanto para CampoDeclaracao (digitado) quanto para os textos
## fixos dos 3 slots-botão (CampoCondicao/AcaoIF/AcaoELSE), para que a
## comparação seja robusta a maiúsculas/minúsculas e espaços.
func _normalizar_texto(texto: String) -> String:
	return texto.strip_edges().replace(" ", "").to_lower()


# ==================================================================
# 9. DICAS
# ==================================================================

## Garante que o RichTextLabel realmente interprete as tags BBCode
## ([color], [b], etc.) em vez de exibi-las como texto literal na tela.
## Esta é a correção do bug relatado: bbcode_enabled precisa estar true
## ANTES de atribuir o texto.
## Dicas com título vazio ("") não repetem o [b][/b] — ficam como uma
## continuação da explicação anterior, sem quebrar a leitura visual.
func _configurar_dicas() -> void:
	if _texto_dicas == null:
		return

	_texto_dicas.bbcode_enabled = true

	var partes: Array[String] = []
	for dica: Array in DICAS:
		var titulo: String = dica[0]
		var texto: String = dica[1]
		if titulo.is_empty():
			partes.append("[color=%s]%s[/color]" % [COR_DICA_TEXTO, texto])
		else:
			partes.append("[color=%s][b]%s[/b][/color] [color=%s]%s[/color]" % [COR_DICA_DESTAQUE, titulo, COR_DICA_TEXTO, texto])

	_texto_dicas.text = "\n\n".join(partes)


func _configurar_desafio() -> void:
	_label_desafio.text = TEXTO_DESAFIO


## O puzzle ensina JAVASCRIPT, não Python. JavaScript abre blocos com "{"
## (não ":") e não depende de indentação. Esta função garante que os
## labels DoisPontosIF/DoisPontosELSE mostrem "{" — mesmo que o texto
## tenha ficado como ":" no editor da cena — sem criar nenhum nó novo,
## apenas ajustando a propriedade `text` dos labels já existentes.
func _configurar_sintaxe_javascript() -> void:
	if _dois_pontos_if != null:
		_dois_pontos_if.text = "{"
	if _dois_pontos_else != null:
		_dois_pontos_else.text = "{"


# ==================================================================
# 10. VALIDAÇÃO
# ==================================================================
# Filosofia: o jogador tem liberdade TOTAL para montar respostas erradas —
# incluindo colocar a opção errada em um slot. Nada disso é bloqueado na
# hora de montar. A validação de certo/errado só acontece aqui, ao
# clicar em "Executar".
#
# O jogador também tem liberdade para escolher o VALOR de `cristal`.
# Maiúsculas/minúsculas e espaços também não importam. O que é
# obrigatório é a ESTRUTURA:
#   let cristal = <número>;
#   if (cristal > 10) { console.log("Maior"); }
#   else { console.log("Menor"); }
# CampoCondicao, AcaoIF e AcaoELSE agora só podem conter texto fixo
# vindo de um clique no PainelOpcoes, então a validação deles é uma
# comparação direta de string (normalizada) contra o texto esperado —
# nada aqui usa eval() nem executa o código digitado.
#
# Como agora cada parte tem uma mensagem própria e detalhada (ver
# MSG_ERRO_* na seção 3), a validação verifica cada parte EM ORDEM e
# mostra em TextoFeedback a mensagem do PRIMEIRO erro encontrado —
# mostrar todas juntas de uma vez ficaria poluído e ilegível.

func _declaracao_esta_correta() -> bool:
	var texto: String = _normalizar_texto(_campo_declaracao.text)
	return _regex_declaracao.search(texto) != null


func _condicao_esta_correta() -> bool:
	return _normalizar_texto(_valor_campo_condicao) == _normalizar_texto(TEXTO_CONDICAO_CORRETA)


func _acao_if_esta_correta() -> bool:
	return _normalizar_texto(_valor_acao_if) == _normalizar_texto(TEXTO_ACAO_IF_CORRETA)


func _acao_else_esta_correta() -> bool:
	return _normalizar_texto(_valor_acao_else) == _normalizar_texto(TEXTO_ACAO_ELSE_CORRETA)


func _validar_puzzle() -> void:
	if _puzzle_resolvido:
		return

	if not _todos_slots_preenchidos() or not _campo_declaracao_preenchido():
		_mostrar_feedback(MSG_CAMPOS_INCOMPLETOS, COR_FEEDBACK_ALERTA)
		return

	# Verificação em ordem: a primeira parte incorreta encontrada define
	# a mensagem exibida. O VALOR de cristal continua livre — só a
	# estrutura é obrigatória.
	if not _declaracao_esta_correta():
		_mostrar_feedback(MSG_ERRO_DECLARACAO, COR_FEEDBACK_ERRO)
		return

	if _valor_slot_if != ESTRUTURA_IF_ESPERADA:
		_mostrar_feedback(MSG_ERRO_IF, COR_FEEDBACK_ERRO)
		return

	if not _condicao_esta_correta():
		_mostrar_feedback(MSG_ERRO_CONDICAO, COR_FEEDBACK_ERRO)
		return

	if not _acao_if_esta_correta():
		_mostrar_feedback(MSG_ERRO_ACAO_IF, COR_FEEDBACK_ERRO)
		return

	if _valor_slot_else != ESTRUTURA_ELSE_ESPERADA:
		_mostrar_feedback(MSG_ERRO_ELSE, COR_FEEDBACK_ERRO)
		return

	if not _acao_else_esta_correta():
		_mostrar_feedback(MSG_ERRO_ACAO_ELSE, COR_FEEDBACK_ERRO)
		return

	# Todas as partes corretas.
	_concluir_puzzle()


# ==================================================================
# 11. FEEDBACK E REINÍCIO DA RESPOSTA
# ==================================================================

## Configura o TextoFeedback (nó já existente, nunca recriado) para que
## mensagens de qualquer tamanho fiquem legíveis:
##   - autowrap: permite quebra de linha automática (palavras inteiras);
##   - alinhamento horizontal e vertical centralizados, como já era o
##     padrão visual do puzzle;
##   - clip_text = false e text_overrun_behavior sem corte: garante que
##     a mensagem NUNCA seja cortada, mesmo em telas menores ou com
##     mensagens de duas linhas.
## Chamada uma única vez em _ready(). A partir daqui, o único ponto do
## script que escreve em TextoFeedback é _mostrar_feedback().
func _configurar_texto_feedback() -> void:
	if _texto_feedback == null:
		return
	_texto_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_feedback.clip_text = false
	_texto_feedback.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


## Único ponto do script que escreve em TextoFeedback. Usada tanto pela
## validação (seção 10) quanto pelos avisos de slot/opção (seções 7/8).
func _mostrar_feedback(mensagem: String, cor: Color) -> void:
	if _texto_feedback == null:
		return
	_texto_feedback.text = mensagem
	_texto_feedback.add_theme_color_override("font_color", cor)


func _on_botao_executar_pressed() -> void:
	_validar_puzzle()


## Estado inicial / reinício completo: os 5 slots voltam a "___",
## CampoDeclaracao é limpo, TODAS as 11 opções ficam visíveis novamente,
## as referências de botão de origem voltam a null, e _puzzle_resolvido
## volta a false — essencial para que o jogador possa clicar em Limpar
## e tentar de novo (inclusive testando combinações erradas) mesmo
## depois de já ter resolvido o puzzle uma vez.
## Usado tanto em _ready() quanto quando o jogador clica em "Limpar".
## Continua sendo o único ponto que reinicia TODOS os slots de uma vez;
## o "desfazer individual" (seção 7) nunca chama esta função.
## ATUALIZAÇÃO 4 (visual): também redesenha os 5 slots no estado
## "vazio" (ver seção 14), para que o Limpar sempre deixe a interface
## visualmente coerente com o estado real dos dados.
func _reiniciar_estado_puzzle() -> void:
	_campo_declaracao.text = ""

	_valor_slot_if = ""
	_valor_campo_condicao = ""
	_valor_acao_if = ""
	_valor_slot_else = ""
	_valor_acao_else = ""

	_botao_origem_slot_if = null
	_botao_origem_campo_condicao = null
	_botao_origem_acao_if = null
	_botao_origem_slot_else = null
	_botao_origem_acao_else = null

	if _slot_if != null:
		_slot_if.text = "___"
		_atualizar_estilo_slot(_slot_if, false)
	if _campo_condicao != null:
		_campo_condicao.text = "___"
		_atualizar_estilo_slot(_campo_condicao, false)
	if _acao_if != null:
		_acao_if.text = "___"
		_atualizar_estilo_slot(_acao_if, false)
	if _slot_else != null:
		_slot_else.text = "___"
		_atualizar_estilo_slot(_slot_else, false)
	if _acao_else != null:
		_acao_else.text = "___"
		_atualizar_estilo_slot(_acao_else, false)

	var todas_opcoes: Array[Button] = [
		_opcao_if, _opcao_else, _opcao_elif, _opcao_while,
		_opcao_condicao, _opcao_console_maior, _opcao_console_menor,
		_opcao_igual, _opcao_maior, _opcao_menor, _opcao_diferente,
	]
	for opcao: Button in todas_opcoes:
		if opcao != null:
			opcao.visible = true
			opcao.disabled = false

	if _texto_feedback != null:
		_texto_feedback.text = ""

	_puzzle_resolvido = false


func _on_botao_limpar_pressed() -> void:
	# "Limpar" continua sendo o único responsável por devolver TODAS as
	# opções usadas à área de opções de uma só vez. O "desfazer
	# individual" por slot (seção 7) é um atalho adicional, não um
	# substituto deste botão.
	_reiniciar_estado_puzzle()


# ==================================================================
# 12. CONCLUSÃO
# ==================================================================

func _concluir_puzzle() -> void:
	_puzzle_resolvido = true
	_mostrar_feedback(MSG_SUCESSO, COR_FEEDBACK_SUCESSO)
	desafio_concluido.emit()


# ==================================================================
# 13. FECHAMENTO
# ==================================================================

func _on_botao_fechar_pressed() -> void:
	queue_free()


# ==================================================================
# 14. VISUAL — TEMA "CAVERNA DE CRISTAL"
# ==================================================================
# Aplica apenas theme overrides (cores, styleboxes) e propriedades
# visuais nos nós já existentes. Não cria nenhum nó novo, não altera
# posição, tamanho, nomes ou estrutura da cena.
#
# A abordagem segue diretamente a usada no Puzzle_cidade (mesma fase do
# jogo): uma função central _caixa() para gerar StyleBoxFlat com bordas
# arredondadas e brilho opcional, estilos separados para os estados
# normal/hover/pressed/focus/disabled, hover PARCIAL (o botão continua
# majoritariamente escuro, só ganhando uma faixa e uma borda mais
# brilhante), e slots com aparência diferente quando vazios e quando
# preenchidos. A única troca é a paleta: azul -> roxo.

## Cria um StyleBoxFlat completo.
## - largura: espessura da borda em todos os lados;
## - brilho: tamanho do glow/sombra roxa (efeito de luz); 0 = sem brilho;
## - largura_esq / largura_baixo: espessura extra só nesses lados (faixa
##   parcial usada no hover, para não pintar o botão inteiro de roxo);
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
		sb.shadow_color = Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.35)
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
	var sb := _caixa(Color(0, 0, 0, 0), COR_ROXO_BRILHO, 2)
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
	_aplicar_estilo_janela_e_barra()
	_aplicar_estilo_desafio()
	_aplicar_borda_paineis()
	_aplicar_estilo_campo_declaracao()
	_aplicar_estilo_botoes_opcoes()
	_aplicar_estilo_slots()
	_aplicar_estilo_botoes_acao()
	_aplicar_estilo_labels_sintaxe()
	_aplicar_estilo_botao_fechar()


## JanelaPuzzle: painel principal, fundo bem escuro e borda roxa com
## brilho discreto. BarraTitulo: mesmo espírito, mas com borda mais
## brilhante/grossa — funciona como o "título" da janela, no mesmo
## destaque usado no título do Puzzle_cidade.
func _aplicar_estilo_janela_e_barra() -> void:
	if _janela_puzzle != null:
		_janela_puzzle.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_ROXO, ESPESSURA_BORDA_PAINEL, 10))
	if _barra_titulo != null:
		_barra_titulo.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, COR_ROXO_BRILHO, 2, 14))


## Desafio funciona como o "título" textual do puzzle: fundo quase
## preto, borda roxa brilhante e texto lilás claro, no mesmo espírito
## dos títulos destacados do Puzzle_cidade.
func _aplicar_estilo_desafio() -> void:
	if _label_desafio == null:
		return
	_label_desafio.add_theme_stylebox_override("normal", _caixa(COR_FUNDO, COR_ROXO_BRILHO, 2, 8, -1, -1, 10, 6))
	_label_desafio.add_theme_color_override("font_color", COR_ROXO_BRILHO)


## Borda roxa arredondada com leve brilho em PainelCodigo, PainelDicas e
## PainelFeedback — fundo sempre COR_PAINEL (preto/roxo bem escuro),
## igual à abordagem de painéis do Puzzle_cidade.
func _aplicar_borda_paineis() -> void:
	var paineis: Array[Panel] = [_painel_codigo, _painel_dicas, _painel_feedback]
	for painel: Panel in paineis:
		if painel == null:
			continue
		painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_ROXO, ESPESSURA_BORDA_PAINEL, 6))


## CampoDeclaracao continua sendo o único campo digitado pelo jogador.
## Recebe o mesmo tratamento visual de um botão normal (fundo escuro,
## borda roxa), com destaque de foco (fundo levemente roxo-escuro,
## borda brilhante) enquanto o jogador digita.
func _aplicar_estilo_campo_declaracao() -> void:
	if _campo_declaracao == null:
		return
	var normal := _caixa(COR_BOTAO, COR_ROXO, 2, 0, -1, -1, 10, 6)
	var foco := _caixa(COR_ROXO_ESCURO, COR_ROXO_BRILHO, 2, 6, -1, -1, 10, 6)
	_campo_declaracao.add_theme_stylebox_override("normal", normal)
	_campo_declaracao.add_theme_stylebox_override("focus", foco)
	_campo_declaracao.add_theme_color_override("font_color", COR_TEXTO)
	_campo_declaracao.add_theme_color_override("font_placeholder_color", COR_ROXO_APAGADO)
	_campo_declaracao.add_theme_color_override("caret_color", COR_ROXO_BRILHO)


## Botões de opção do PainelOpcoes (if/else/elif/while/condição/
## console.log/operadores): mesmo estilo padrão usado nos botões de
## ação (ver _estilizar_botao_padrao), para que toda a janela fale a
## mesma linguagem visual.
func _aplicar_estilo_botoes_opcoes() -> void:
	var botoes_opcoes: Array[Button] = [
		_opcao_if, _opcao_else, _opcao_elif, _opcao_while,
		_opcao_condicao, _opcao_console_maior, _opcao_console_menor,
		_opcao_igual, _opcao_maior, _opcao_menor, _opcao_diferente,
	]
	for botao: Button in botoes_opcoes:
		if botao == null:
			continue
		_estilizar_botao_padrao(botao)


## BotaoExecutar e Limpar recebem o mesmo tratamento padrão dos botões
## de opção, mantendo a interface inteira consistente.
func _aplicar_estilo_botoes_acao() -> void:
	if _botao_executar != null:
		_estilizar_botao_padrao(_botao_executar)
	if _botao_limpar != null:
		_estilizar_botao_padrao(_botao_limpar)


## Estilo padrão compartilhado por botões de opção e pelos botões de
## ação (Executar/Limpar):
##   NORMAL: fundo quase preto, borda roxa fina, texto claro;
##   HOVER (parcial): fundo ainda majoritariamente escuro, ganhando um
##     tom roxo-escuro e uma faixa mais grossa à esquerda/embaixo, borda
##     mais brilhante e glow discreto — nunca pinta o botão inteiro;
##   PRESSED: roxo mais forte, claramente diferente do hover;
##   FOCUS: só a borda brilhante, sem destruir o fundo escuro;
##   DISABLED: roxo apagado, texto menos intenso.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_ROXO, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_ROXO_ESCURO, COR_ROXO_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_ROXO_FORTE, COR_ROXO, 2, 0, -1, -1, 10, 6)
	var desabilitado := _caixa(COR_FUNDO, COR_ROXO_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos_botao(botao, normal, hover, pressed, _caixa_foco(), desabilitado, COR_TEXTO)


## Aplica o estado visual inicial dos 5 slots (SlotIF, CampoCondicao,
## AcaoIF, SlotELSE, AcaoELSE) de acordo com o conteúdo atual de cada
## um. Chamada uma vez em _aplicar_estilo_visual(); depois disso, cada
## clique de opção/slot chama diretamente _atualizar_estilo_slot()
## (seções 7 e 11) para manter a aparência sincronizada com os dados.
func _aplicar_estilo_slots() -> void:
	_atualizar_estilo_slot(_slot_if, _valor_slot_if != "")
	_atualizar_estilo_slot(_campo_condicao, _valor_campo_condicao != "")
	_atualizar_estilo_slot(_acao_if, _valor_acao_if != "")
	_atualizar_estilo_slot(_slot_else, _valor_slot_else != "")
	_atualizar_estilo_slot(_acao_else, _valor_acao_else != "")


## Redesenha UM slot no estado vazio ou preenchido, igual à lógica dos
## slots do Puzzle_cidade:
##   VAZIO: fundo preto, borda roxa apagada, texto discreto;
##   PREENCHIDO: fundo preto, borda roxa mais forte com brilho, texto em
##     roxo claro/lilás, hover mais destacado (mesmo hover parcial dos
##     botões).
## Puramente visual — não interfere em como/quando um slot é preenchido
## ou esvaziado (isso continua 100% na seção 7).
func _atualizar_estilo_slot(slot: Button, preenchido: bool) -> void:
	if slot == null:
		return
	if not preenchido:
		var normal := _caixa(COR_FUNDO, COR_ROXO_APAGADO, 1, 0, -1, -1, 10, 6)
		var hover := _caixa(COR_FUNDO, COR_ROXO, 2, 0, -1, -1, 10, 6)
		_definir_estilos_botao(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO_DESABILITADO)
	else:
		var normal := _caixa(COR_FUNDO, COR_ROXO, 3, 8, -1, -1, 10, 6)
		var hover := _caixa(COR_ROXO_ESCURO, COR_ROXO_BRILHO, 3, 10, 7, 6, 10, 6)
		var pressed := _caixa(COR_ROXO_FORTE, COR_ROXO, 3, 0, -1, -1, 10, 6)
		_definir_estilos_botao(slot, normal, hover, pressed, _caixa_foco(), normal, COR_ROXO_BRILHO)


## DoisPontosIF/DoisPontosELSE ("{"): texto em roxo claro/lilás
## brilhante, coerente com o resto da sintaxe destacada.
func _aplicar_estilo_labels_sintaxe() -> void:
	if _dois_pontos_if != null:
		_dois_pontos_if.add_theme_color_override("font_color", COR_TEXTO_CODIGO)
	if _dois_pontos_else != null:
		_dois_pontos_else.add_theme_color_override("font_color", COR_TEXTO_CODIGO)


## BotaoFechar é um TextureButton — não usa StyleBoxFlat como os Button
## comuns (normal/hover/pressed dele são texturas definidas no editor).
## Para não arriscar alterar seu funcionamento, aplicamos só uma
## modulação de cor sutil (tint), sem trocar textura, sinal ou hitbox.
func _aplicar_estilo_botao_fechar() -> void:
	if _botao_fechar == null:
		return
	_botao_fechar.self_modulate = COR_TEXTO


## PainelOpcoes continua sendo um Control puro (sem stylebox de "panel"
## próprio) — a borda/fundo dele é desenhada manualmente em _draw(),
## sem criar nenhum nó novo. Agora com fundo escuro, cantos
## arredondados e um brilho discreto, seguindo a mesma linguagem visual
## usada nos demais painéis.
func _preparar_borda_painel_opcoes() -> void:
	if _painel_opcoes == null:
		return
	_estilo_borda_opcoes = _caixa(COR_PAINEL, COR_ROXO, ESPESSURA_BORDA_PAINEL, 6)
	if not _painel_opcoes.resized.is_connected(queue_redraw):
		_painel_opcoes.resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if _painel_opcoes == null or _estilo_borda_opcoes == null:
		return
	# Control (2D) não tem to_local()/to_global() — só Node3D tem. O
	# equivalente em 2D é converter manualmente pela transform global.
	var posicao_local: Vector2 = get_global_transform().affine_inverse() * _painel_opcoes.global_position
	var retangulo: Rect2 = Rect2(posicao_local, _painel_opcoes.size)
	draw_style_box(_estilo_borda_opcoes, retangulo)
