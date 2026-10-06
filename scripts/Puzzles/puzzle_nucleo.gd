extends Control

## Puzzle_Classes — Puzzle de CLASSES do CodePlay (Fase 7, Núcleo do Sistema).
##
## MECÂNICA REUTILIZADA DO Puzzle_cidade (Funções), EXATAMENTE:
## - Clicar numa opção coloca o texto dela no PRIMEIRO slot vazio (na
##   ordem Slot1 -> Slot7). Não existe "selecionar um slot primeiro".
## - Clicar num slot JÁ PREENCHIDO o esvazia (slot vazio clicado não
##   faz nada). O slot removido fica vazio e não reorganiza os outros.
## - slot_conteudo guarda, para cada slot, a CHAVE da opção que está
##   nele (ex.: "Opcao2"), ou "" se estiver vazio — igual ao Funções.
## - botao_executar só libera o sinal desafio_concluido depois de
##   comparar os 7 slots com a resposta correta; puzzle_ja_concluido
##   evita emitir o sinal mais de uma vez.
## - Toda a estética (StyleBoxFlat criado por código para os estados
##   normal/hover/pressed/focus/disabled dos botões, e vazio/preenchido
##   dos slots) segue a MESMA estrutura de funções (_caixa, _caixa_foco,
##   _definir_estilos, _estilizar_botao_padrao, _atualizar_estilo_slot)
##   do Puzzle_cidade, só trocando a paleta azul pela paleta ciano/
##   metálica já usada na cena Puzzle_Classes.tscn.
##
## ÚNICA ADAPTAÇÃO REAL DE MECÂNICA (pedida explicitamente):
## - No Funções, a opção usada é desabilitada (uso único). Aqui as
##   opções NUNCA são desabilitadas ao serem usadas, porque "nome"
##   (Opcao2) precisa preencher Slot2 E Slot4, e "nivel" (Opcao3)
##   precisa preencher Slot3 E Slot6. Fora esse ponto, a interação é
##   idêntica à do Funções.
##
## Não cria, remove ou renomeia nenhum nó da cena. Não recria a
## interface. Apenas controla os nós que já existem em Puzzle_Classes.tscn.


# --- Configuração do puzzle -------------------------------------------------

## Resposta correta de cada slot, na ordem Slot1 -> Slot7.
## class Jogador { constructor(nome, nivel) { this.nome = "Pedro"; this.nivel = 100; } }
const RESPOSTA_CORRETA: Array[String] = [
	"Jogador",
	"nome",
	"nivel",
	"nome",
	"\"Pedro\"",
	"nivel",
	"100",
]

## Mapeia o nome de cada botão de PainelOpcoes (nome exato do nó na
## cena) para o texto de código que ele representa — mesmo papel que o
## dicionário OPCOES tinha no Puzzle_cidade.
const OPCOES: Dictionary = {
	"Opcao1": "Jogador",
	"Opcao2": "nome",
	"Opcao3": "nivel",
	"Opcao4": "\"Pedro\"",
	"Opcao5": "100",
	"Opcao6": "vida",
	"Opcao7": "idade",
	"Opcao8": "ativo",
	"Opcao9": "\"João\"",
	"Opcao10": "50",
	"Opcao11": "function",
}

## Textos de feedback, no mesmo padrão do Puzzle_cidade.
const FEEDBACK_INICIAL := "Monte o código da classe Jogador preenchendo os espaços."
const FEEDBACK_INCOMPLETO := "Código incompleto! Preencha todos os espaços."
const FEEDBACK_INCORRETO := "Código incorreto! Verifique a ordem das opções."
const FEEDBACK_CORRETO := "✓ DESAFIO CONCLUÍDO!"


# --- Paleta visual (PRETO + CIANO/METÁLICO), mesma identidade da cena -------

const COR_FUNDO := Color("070b0d")
const COR_BOTAO := Color("10181b")
const COR_CIANO := Color("4fd8e0")           # ciano principal (bordas)
const COR_CIANO_BRILHO := Color("a0f0f5")    # ciano mais brilhante (hover/focus)
const COR_CIANO_APAGADO := Color("2c4046")   # ciano discreto (slot vazio, desabilitado)
const COR_CIANO_ESCURO := Color("132329")    # tom escuro para o hover parcial
const COR_CIANO_FORTE := Color("1c363c")     # ciano mais forte/escuro (pressed)
const COR_TEXTO := Color("e8f0f2")
const COR_TEXTO_DESABILITADO := Color("6f7e82")

const RAIO_BORDA := 6


# --- Sinal -------------------------------------------------------------------

## Emitido quando o puzzle é resolvido corretamente, seguindo o mesmo padrão
## usado pelos outros puzzles do CodePlay (ex.: Puzzle_cidade) para avisar
## o PC / GameManager que a fase pode progredir.
signal desafio_concluido


# --- Estado interno ------------------------------------------------------------

## Para cada slot (índice 0 a 6 = Slot1 a Slot7), guarda a CHAVE da opção
## que está nele (ex.: "Opcao2"), ou "" se o slot estiver vazio.
## É esse array que permite remover um slot do meio sem reorganizar os
## outros — igual ao Puzzle_cidade.
var slot_conteudo: Array[String] = ["", "", "", "", "", "", ""]

## Evita emitir desafio_concluido mais de uma vez caso o jogador clique
## em Executar novamente depois de já ter acertado.
var puzzle_ja_concluido := false


# --- Referências aos nós ------------------------------------------------------

@onready var feedback_label: Label = $Feedback

@onready var slots: Array[Button] = [
	$PainelCodigo/Linha1/Slot1,
	$PainelCodigo/Linha2/Slot2,
	$PainelCodigo/Linha2/Slot3,
	$PainelCodigo/Linha4/Slot4,
	$PainelCodigo/Linha4/Slot5,
	$PainelCodigo/Linha5/Slot6,
	$PainelCodigo/Linha5/Slot7,
]

## Botões de opção, indexados pelo mesmo nome usado em OPCOES.
@onready var botoes_opcoes: Dictionary = {
	"Opcao1": $PainelOpcoes/Opcao1,
	"Opcao2": $PainelOpcoes/Opcao2,
	"Opcao3": $PainelOpcoes/Opcao3,
	"Opcao4": $PainelOpcoes/Opcao4,
	"Opcao5": $PainelOpcoes/Opcao5,
	"Opcao6": $PainelOpcoes/Opcao6,
	"Opcao7": $PainelOpcoes/Opcao7,
	"Opcao8": $PainelOpcoes/Opcao8,
	"Opcao9": $PainelOpcoes/Opcao9,
	"Opcao10": $PainelOpcoes/Opcao10,
	"Opcao11": $PainelOpcoes/Opcao11,
}

@onready var botao_executar: Button = $BotaoExecutar
@onready var botao_limpar: Button = $BotaoLimpar


func _ready() -> void:
	_conectar_sinais()
	_aplicar_estetica()
	feedback_label.text = FEEDBACK_INICIAL


func _conectar_sinais() -> void:
	# Um clique em cada opção chama _on_opcao_pressionada com o nome dela.
	for nome_opcao in botoes_opcoes.keys():
		var botao: Button = botoes_opcoes[nome_opcao]
		botao.pressed.connect(_on_opcao_pressionada.bind(nome_opcao))

	# Um clique em cada slot chama _on_slot_pressionado com o índice dele.
	for indice in range(slots.size()):
		slots[indice].pressed.connect(_on_slot_pressionado.bind(indice))

	botao_executar.pressed.connect(_on_botao_executar_pressed)
	botao_limpar.pressed.connect(_on_botao_limpar_pressed)


# --- Estética (tudo por StyleBoxFlat + theme overrides) ------------------------
# Mesma estrutura de funções do Puzzle_cidade (_caixa, _caixa_foco,
# _definir_estilos, _estilizar_botao_padrao, _atualizar_estilo_slot), só
# trocando a paleta azul pela paleta ciano/metálica da cena Puzzle_Classes.
# Não mexe em posição, tamanho ou estrutura de nenhum nó, e não sobrescreve
# o Theme dos painéis (PainelCodigo/PainelObjetivo/PainelOpcoes/PainelDica),
# que já vem pronto da cena.

func _aplicar_estetica() -> void:
	# Botões de opção.
	for nome_opcao in botoes_opcoes.keys():
		_estilizar_botao_padrao(botoes_opcoes[nome_opcao])

	# Botões Executar e Limpar.
	_estilizar_botao_padrao(botao_executar)
	_estilizar_botao_padrao(botao_limpar)

	# Slots (aparência depende de estarem vazios ou preenchidos).
	for indice in range(slots.size()):
		_atualizar_estilo_slot(indice)


## Cria um StyleBoxFlat.
## - largura: espessura da borda em todos os lados;
## - brilho: tamanho da sombra ciano (efeito de luz); 0 = sem brilho;
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
		sb.shadow_color = Color(COR_CIANO.r, COR_CIANO.g, COR_CIANO.b, 0.35)
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
	var sb := _caixa(Color(0, 0, 0, 0), COR_CIANO_BRILHO, 2)
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


## Botões de opção, Executar e Limpar.
## Hover PARCIAL: o botão continua escuro, mas ganha borda mais brilhante,
## faixa mais grossa à esquerda e embaixo e um tom ciano bem escuro no fundo.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_CIANO, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_CIANO_ESCURO, COR_CIANO_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_CIANO_FORTE, COR_CIANO, 2, 0, -1, -1, 10, 6)
	var disabled := _caixa(COR_FUNDO, COR_CIANO_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


## Slot vazio: preto, borda ciano fina/discreta.
## Slot preenchido: preto, borda ciano grossa com brilho e texto em ciano claro.
## O hover do slot preenchido usa o mesmo destaque parcial dos botões.
func _atualizar_estilo_slot(indice: int) -> void:
	var slot := slots[indice]

	if slot_conteudo[indice] == "":
		var normal := _caixa(COR_FUNDO, COR_CIANO_APAGADO, 1, 0, -1, -1, 10, 6)
		var hover := _caixa(COR_FUNDO, COR_CIANO, 2, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)
	else:
		var normal := _caixa(COR_FUNDO, COR_CIANO, 3, 8, -1, -1, 10, 6)
		var hover := _caixa(COR_CIANO_ESCURO, COR_CIANO_BRILHO, 3, 10, 7, 6, 10, 6)
		var pressed := _caixa(COR_CIANO_FORTE, COR_CIANO, 3, 0, -1, -1, 10, 6)
		_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_CIANO_BRILHO)


# --- Lógica dos slots ----------------------------------------------------------

## Chamado quando o jogador clica em uma opção disponível.
## Coloca a opção no primeiro slot vazio (Slot1 -> Slot7).
## DIFERENÇA DELIBERADA em relação ao Puzzle_cidade: o botão da opção
## NÃO é desabilitado depois de usado, porque "nome" (Opcao2) e "nivel"
## (Opcao3) precisam preencher dois slots cada. Fora isso, a lógica é
## idêntica: se todos os slots já estiverem ocupados, simplesmente não
## há onde colocar e nada acontece.
func _on_opcao_pressionada(nome_opcao: String) -> void:
	var indice_slot_vazio := slot_conteudo.find("")
	if indice_slot_vazio == -1:
		return

	slot_conteudo[indice_slot_vazio] = nome_opcao
	slots[indice_slot_vazio].text = OPCOES[nome_opcao]
	_atualizar_estilo_slot(indice_slot_vazio)


## Chamado quando o jogador clica em um slot (para remover o que estiver
## nele). Slots vazios clicados não fazem nada. O slot removido fica
## vazio e NÃO reorganiza os outros slots — igual ao Puzzle_cidade.
func _on_slot_pressionado(indice: int) -> void:
	if slot_conteudo[indice] == "":
		return

	slot_conteudo[indice] = ""
	slots[indice].text = ""
	_atualizar_estilo_slot(indice)


# --- LIMPAR --------------------------------------------------------------------

## Botão Limpar: não existe no Puzzle_cidade (lá o jogador só remove um
## slot de cada vez clicando nele), mas é exigido pela cena Puzzle_Classes.
## Reaproveita a mesma lógica de esvaziar um slot, aplicada aos 7 de uma
## vez, e limpa o feedback.
func _on_botao_limpar_pressed() -> void:
	for indice in range(slot_conteudo.size()):
		slot_conteudo[indice] = ""
		slots[indice].text = ""
		_atualizar_estilo_slot(indice)

	feedback_label.text = ""


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
## Igual ao Puzzle_cidade, não trava a interface depois de concluído —
## puzzle_ja_concluido só impede que o sinal seja emitido mais de uma vez.
func _concluir_puzzle() -> void:
	if puzzle_ja_concluido:
		return
	puzzle_ja_concluido = true
	desafio_concluido.emit()
