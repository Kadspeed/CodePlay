extends Control

## Puzzle_Classes — Puzzle de CLASSES do CodePlay (Fase 7, Núcleo do Sistema).
## Godot 4.7 | GDScript
##
## MECÂNICA (preenchimento automático em ordem):
## 1. Clicar em uma OPÇÃO coloca o texto dela no PRIMEIRO espaço vazio, na
##    ordem do código (Slot1 -> Slot7). Qualquer opção pode ir para qualquer
##    espaço: o puzzle não confere a resposta na hora de colocar.
## 2. As opções nunca são desabilitadas, então "nome" e "nivel" podem ser
##    usados quantas vezes forem necessários.
## 3. Clicar em um espaço PREENCHIDO o esvazia (os outros não se movem); a
##    próxima opção clicada ocupa o primeiro espaço vazio, que pode ser esse.
## 4. Cada espaço guarda sua própria resposta (slot_conteudo). A validação
##    aceita as 36 versões corretas do enunciado (ver _resposta_esta_correta),
##    usando as CHAVES internas das opções ("Opcao1"...), nunca o texto dos botões.
## 5. Executar valida; Limpar reinicia tudo; Pedir Dica mostra dicas graduais.
## 6. desafio_concluido é emitido uma única vez, somente com tudo correto.
##
## Código a montar:
##   class Jogador {
##       constructor(nome, nivel) {
##           this.nome = "Pedro";
##           this.nivel = 100;
##       }
##   }
##
## Este script só controla nós já existentes em puzzle_nucleo.tscn.

# --- Sinal -------------------------------------------------------------------

## Emitido quando o puzzle é resolvido corretamente (padrão dos puzzles do CodePlay).
signal desafio_concluido


# --- Configuração do puzzle --------------------------------------------------

## Mapeia o nome de cada botão de PainelOpcoes para o texto de código dele.
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

## REGRAS DE RESPOSTA (aceitam as 36 versões corretas do enunciado).
## Tudo usa as chaves internas das opções, nunca o texto dos botões.
## Ordem dos espaços: 0 = nome da classe | 1, 2 = parâmetros do constructor |
## 3 = propriedade A | 4 = valor de A | 5 = propriedade B | 6 = valor de B.
const OPCAO_CLASSE := "Opcao1"      # Jogador
const OPCAO_NOME := "Opcao2"        # nome
const OPCAO_NIVEL := "Opcao3"       # nivel

## Valores aceitos para cada propriedade: literais do tipo certo ou o
## parâmetro de mesmo nome (this.nome = nome).
const VALORES_NOME: Array[String] = ["Opcao4", "Opcao9", "Opcao2"]    # "Pedro", "João", nome
const VALORES_NIVEL: Array[String] = ["Opcao5", "Opcao10", "Opcao3"]  # 100, 50, nivel

## Texto que já existe em PainelDica/TextoDica na cena (restaurado ao limpar).
const TEXTO_DICA_INICIAL := "Uma classe é um molde para criar objetos. O constructor define os valores iniciais de suas propriedades."

## Dicas progressivas: da ideia geral para a estrutura, sem entregar a sequência.
const DICAS: Array[String] = [
	"Uma classe começa com a palavra-chave class, seguida do nome que você escolheu para ela.",
	"O constructor recebe os parâmetros usados para inicializar um objeto. Eles ficam entre os parênteses.",
	"A palavra-chave this permite acessar as propriedades do objeto atual. this.nome é a propriedade nome.",
	"Cada linha com this tem a forma this.propriedade = valor; O valor pode ser um texto entre aspas ou um número.",
	"Você pode usar a mesma opção em mais de um espaço. Os nomes das propriedades repetem os parâmetros do constructor.",
]

## Textos de feedback.
const FEEDBACK_INICIAL := "Clique nas opções para preencher os espaços do código, em ordem. Clique em um espaço preenchido para esvaziá-lo."
const FEEDBACK_TUDO_PREENCHIDO := "Todos os espaços estão preenchidos. Clique em Executar, ou em um espaço para esvaziá-lo."
const FEEDBACK_ESPACO_ESVAZIADO := "Espaço esvaziado. A próxima opção ocupará o primeiro espaço vazio."
const FEEDBACK_LIMPO := "Código reiniciado. Clique em uma opção para começar."
const FEEDBACK_INCOMPLETO := "Ainda existem espaços vazios."
const FEEDBACK_INCORRETO := "Algumas partes estão incorretas. Revise o código."
const FEEDBACK_CORRETO := "DESAFIO CONCLUÍDO!"


# --- Paleta visual (PRETO + CIANO/METÁLICO) ----------------------------------

const COR_FUNDO := Color("070b0d")
const COR_BOTAO := Color("10181b")
const COR_CIANO := Color("4fd8e0")           # ciano principal (bordas)
const COR_CIANO_BRILHO := Color("a0f0f5")    # ciano claro (destaques)
const COR_CIANO_APAGADO := Color("2c4046")   # bordas discretas
const COR_CIANO_ESCURO := Color("132329")    # fundo de hover
const COR_CIANO_FORTE := Color("1c363c")     # fundo de elementos destacados
const COR_TEXTO := Color("e8f0f2")
const COR_TEXTO_DESABILITADO := Color("6f7e82")

const RAIO_BORDA := 6


# --- Estado interno ----------------------------------------------------------

## Para cada espaço (0 a 6 = Slot1 a Slot7), a CHAVE da opção que está nele
## (ex.: "Opcao2"), ou "" se estiver vazio. Cada espaço é independente.
var slot_conteudo: Array[String] = ["", "", "", "", "", "", ""]

## Quantas dicas já foram mostradas.
var nivel_dica: int = 0

## Evita emitir desafio_concluido mais de uma vez.
var puzzle_ja_concluido := false


# --- Referências aos nós -----------------------------------------------------

@onready var feedback_label: Label = $Feedback
@onready var texto_dica: RichTextLabel = $PainelDica/TextoDica

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
@onready var botao_dica: Button = $PainelDica/BotaoDica


# --- Inicialização -----------------------------------------------------------

func _ready() -> void:
	_conectar_sinais()
	_aplicar_estetica()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mostrar_feedback(FEEDBACK_INICIAL)


func _conectar_sinais() -> void:
	for nome_opcao in botoes_opcoes.keys():
		var botao: Button = botoes_opcoes[nome_opcao]
		botao.pressed.connect(_on_opcao_pressionada.bind(nome_opcao))

	for indice in range(slots.size()):
		slots[indice].pressed.connect(_on_slot_pressionado.bind(indice))

	botao_executar.pressed.connect(_on_botao_executar_pressed)
	botao_limpar.pressed.connect(_on_botao_limpar_pressed)
	botao_dica.pressed.connect(_on_botao_dica_pressed)


# --- Preenchimento e remoção -------------------------------------------------

## Clique em uma opção: vai para o primeiro espaço vazio (Slot1 -> Slot7).
## Qualquer opção pode ocupar qualquer espaço. As opções nunca são
## desabilitadas, então podem ser reutilizadas.
func _on_opcao_pressionada(nome_opcao: String) -> void:
	var indice := slot_conteudo.find("")
	if indice == -1:
		_mostrar_feedback(FEEDBACK_TUDO_PREENCHIDO)
		return

	_preencher_slot(indice, nome_opcao)
	if slot_conteudo.has(""):
		_mostrar_feedback("%s colocado no espaço %d." % [OPCOES[nome_opcao], indice + 1])
	else:
		_mostrar_feedback(FEEDBACK_TUDO_PREENCHIDO)


## Clique em um espaço preenchido: esvazia só esse espaço. Espaço vazio não faz nada.
func _on_slot_pressionado(indice: int) -> void:
	if slot_conteudo[indice] == "":
		return
	_esvaziar_slot(indice)
	_mostrar_feedback(FEEDBACK_ESPACO_ESVAZIADO)


func _preencher_slot(indice: int, nome_opcao: String) -> void:
	slot_conteudo[indice] = nome_opcao
	_atualizar_slot(indice)


func _esvaziar_slot(indice: int) -> void:
	slot_conteudo[indice] = ""
	_atualizar_slot(indice)


# --- Aparência dos espaços ---------------------------------------------------

## Atualiza texto e estilo de um espaço conforme o conteúdo.
func _atualizar_slot(indice: int) -> void:
	var slot := slots[indice]
	var conteudo := slot_conteudo[indice]
	slot.text = OPCOES[conteudo] if conteudo != "" else ""
	_atualizar_estilo_slot(indice)


## Vazio: preto, borda discreta. Preenchido: borda ciano com brilho.
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


# --- Limpar ------------------------------------------------------------------

## Reinicia o desafio: esvazia tudo e restaura as dicas.
## Não afeta puzzle_ja_concluido (o sinal nunca é emitido duas vezes).
func _on_botao_limpar_pressed() -> void:
	for indice in range(slot_conteudo.size()):
		slot_conteudo[indice] = ""
		_atualizar_slot(indice)

	nivel_dica = 0
	texto_dica.text = TEXTO_DICA_INICIAL
	_mostrar_feedback(FEEDBACK_LIMPO)


# --- Dicas -------------------------------------------------------------------

## Cada clique mostra a próxima dica; depois da última, a última permanece.
func _on_botao_dica_pressed() -> void:
	nivel_dica = mini(nivel_dica + 1, DICAS.size())
	texto_dica.text = "Dica %d/%d: %s" % [nivel_dica, DICAS.size(), DICAS[nivel_dica - 1]]


# --- Validação ---------------------------------------------------------------

func _on_botao_executar_pressed() -> void:
	if slot_conteudo.has(""):
		_mostrar_feedback(FEEDBACK_INCOMPLETO)
		return

	if _resposta_esta_correta():
		_mostrar_feedback(FEEDBACK_CORRETO, true)
		_concluir_puzzle()
	else:
		_mostrar_feedback(FEEDBACK_INCORRETO)


## Valida o estado final (independe da ordem dos cliques). Aceita:
## - classe Jogador;
## - parâmetros nome e nivel em qualquer ordem (sem repetir);
## - propriedades nome e nivel em qualquer ordem de linha (sem repetir);
## - cada propriedade com um valor do tipo certo ou o parâmetro correspondente.
func _resposta_esta_correta() -> bool:
	if slot_conteudo[0] != OPCAO_CLASSE:
		return false
	if not _e_par_nome_nivel(slot_conteudo[1], slot_conteudo[2]):
		return false
	if not _e_par_nome_nivel(slot_conteudo[3], slot_conteudo[5]):
		return false
	return _valor_combina(slot_conteudo[3], slot_conteudo[4]) \
			and _valor_combina(slot_conteudo[5], slot_conteudo[6])


## true se os dois espaços contêm nome e nivel, em qualquer ordem.
func _e_par_nome_nivel(a: String, b: String) -> bool:
	return (a == OPCAO_NOME and b == OPCAO_NIVEL) or (a == OPCAO_NIVEL and b == OPCAO_NOME)


## true se o valor é aceito para a propriedade (nome recebe texto/nome; nivel recebe número/nivel).
func _valor_combina(propriedade: String, valor: String) -> bool:
	if propriedade == OPCAO_NOME:
		return VALORES_NOME.has(valor)
	if propriedade == OPCAO_NIVEL:
		return VALORES_NIVEL.has(valor)
	return false


## Avisa o resto do projeto (PC / GameManager). Emite uma única vez.
func _concluir_puzzle() -> void:
	if puzzle_ja_concluido:
		return
	puzzle_ja_concluido = true
	desafio_concluido.emit()


# --- Feedback ----------------------------------------------------------------

## Mostra uma mensagem. Em caso de sucesso, usa o ciano claro com contorno.
func _mostrar_feedback(texto: String, sucesso: bool = false) -> void:
	feedback_label.text = texto
	if sucesso:
		feedback_label.add_theme_color_override("font_color", COR_CIANO_BRILHO)
		feedback_label.add_theme_color_override("font_outline_color", COR_CIANO_FORTE)
		feedback_label.add_theme_constant_override("outline_size", 4)
	else:
		feedback_label.add_theme_color_override("font_color", COR_TEXTO)
		feedback_label.add_theme_constant_override("outline_size", 0)


# --- Estética (StyleBoxFlat + theme overrides) --------------------------------

func _aplicar_estetica() -> void:
	for nome_opcao in botoes_opcoes.keys():
		_estilizar_botao_padrao(botoes_opcoes[nome_opcao])

	_estilizar_botao_padrao(botao_executar)
	_estilizar_botao_padrao(botao_limpar)
	_estilizar_botao_padrao(botao_dica)

	for indice in range(slots.size()):
		_atualizar_slot(indice)


## Cria um StyleBoxFlat (borda, brilho ciano opcional, margens internas).
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


## Contorno de foco: só a borda, sem preencher.
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


## Botões de opção, Executar, Limpar e Dica.
func _estilizar_botao_padrao(botao: Button) -> void:
	var normal := _caixa(COR_BOTAO, COR_CIANO, 2, 0, -1, -1, 10, 6)
	var hover := _caixa(COR_CIANO_ESCURO, COR_CIANO_BRILHO, 2, 8, 6, 5, 10, 6)
	var pressed := _caixa(COR_CIANO_FORTE, COR_CIANO, 2, 0, -1, -1, 10, 6)
	var disabled := _caixa(COR_FUNDO, COR_CIANO_APAGADO, 1, 0, -1, -1, 10, 6)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)
