extends Control
## Puzzle da Fortaleza Arcana — desafios de loop FOR e WHILE (versão para iniciantes).
## Godot 4.7 | GDScript
##
## COMO FUNCIONA
## - Dois desafios em sequência: FOR (1) e WHILE (2). Só o desafio atual fica
##   visível; o progresso aparece nos indicadores (chips) da barra de progresso.
## - As linhas fixas do código ("let quantidade = 10;", "console.log(...)")
##   já vêm prontas. O jogador só completa os espaços destacados (slots).
## - Cada bloco do painel de opções pertence a UM espaço (início, condição ou
##   passo). Ao clicar num bloco, ele vai para o espaço dele; se o espaço já
##   estiver ocupado, o jogador é avisado e precisa retirar o bloco antes
##   (clicando no espaço preenchido). Blocos errados também podem ser usados.
## - A validação usa o NOME DO NODE do botão (opcao.name), nunca o texto
##   visível. Os nomes ficam nas constantes BLOCOS_* e RESPOSTA_* abaixo.
## - Testar: verifica o desafio atual, simula a saída e avança FOR -> WHILE.
##   NUNCA conclui o puzzle.
## - Executar: faz a mesma verificação e, quando o WHILE está correto (com o
##   FOR já resolvido), conclui o puzzle e emite desafio_concluido UMA vez.
## - Limpar: devolve os blocos do desafio atual ao painel; nunca mexe em um
##   desafio já concluído.
## - Dica: mostra dicas progressivas (3 níveis) do desafio atual. Respostas
##   erradas também liberam a próxima dica automaticamente.
##
## Solução FOR:                         Solução WHILE:
##   let quantidade = 10;                 let runa = 1;
##   for (i = 1; i <= quantidade; i++) {  while (runa <= 10) {
##       console.log(i);                      console.log(runa);
##   }                                        runa++;
##                                        }

signal desafio_concluido

# Quando true, _validar() imprime no Output qual espaço não bateu.
const DEBUG_VALIDACAO := false

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO DOS DESAFIOS
# ---------------------------------------------------------------------------
const PLACEHOLDER := "___"

# Ordem dos espaços (slots) de cada desafio.
const SLOTS_FOR: Array[String] = ["Inicio", "Condicao", "Incremento"]
const SLOTS_WHILE: Array[String] = ["Condicao", "Incremento"]

# Nome amigável de cada espaço (usado nas mensagens).
const NOMES_SLOT := {
	"Inicio": "início do contador",
	"Condicao": "condição",
	"Incremento": "passo (incremento)",
}

# Bloco (Node.name em OpcoesFor/OpcoesWhile) -> espaço ao qual ele pertence.
const BLOCOS_FOR := {
	"For_i_igual_1": "Inicio",
	"For_i_igual_0": "Inicio",
	"For_i_menor_igual_quantidade": "Condicao",
	"For_i_menor_quantidade": "Condicao",
	"For_i_mais_mais": "Incremento",
	"For_i_menos_menos": "Incremento",
}
const BLOCOS_WHILE := {
	"While_runa_menor_igual_10": "Condicao",
	"While_runa_menor_10": "Condicao",
	"While_runa_maior_10": "Condicao",
	"While_runa_mais_mais": "Incremento",
	"While_runa_menos_menos": "Incremento",
}

# Respostas corretas: espaço -> Node.name do bloco esperado.
const RESPOSTA_FOR := {
	"Inicio": "For_i_igual_1",
	"Condicao": "For_i_menor_igual_quantidade",
	"Incremento": "For_i_mais_mais",
}
const RESPOSTA_WHILE := {
	"Condicao": "While_runa_menor_igual_10",
	"Incremento": "While_runa_mais_mais",
}

# Mensagem específica para cada bloco errado (explica o PORQUÊ).
const MENSAGENS_ERRO := {
	"For_i_igual_0": "O contador começa em 0, mas a sequência deve começar em 1.",
	"For_i_menor_quantidade": "Com \"menor que\" o laço para antes do 10. O número final também precisa aparecer.",
	"For_i_menos_menos": "O contador está diminuindo. Ele precisa aumentar de 1 em 1.",
	"While_runa_menor_10": "Com \"menor que 10\" o laço para no 9. O 10 também precisa aparecer.",
	"While_runa_maior_10": "runa começa em 1, então \"maior que 10\" já começa falsa e o laço nem executa.",
	"While_runa_menos_menos": "runa está diminuindo, então o laço nunca terminaria. Ela precisa aumentar.",
}

# Dicas progressivas (da mais geral para a mais direta).
const DICAS_FOR: Array[String] = [
	"O laço for tem 3 partes dentro dos parênteses: onde o contador começa, até quando ele continua e como ele muda a cada volta.",
	"O contador i deve começar em 1, continuar enquanto não passar de quantidade (que vale 10) e aumentar de 1 em 1.",
	"Atenção ao símbolo da condição: \"menor OU IGUAL\" inclui o número final. Para aumentar 1 a cada volta, procure o bloco com ++.",
]
const DICAS_WHILE: Array[String] = [
	"O while repete enquanto a condição for verdadeira. Antes de cada volta, o computador pergunta: a condição ainda é verdadeira?",
	"runa começa em 1 e a contagem deve ir até 10. A condição precisa continuar verdadeira enquanto runa não passar de 10.",
	"Se runa nunca mudar, a condição nunca fica falsa. Dentro do laço, runa precisa aumentar 1 a cada volta (procure o bloco com ++).",
]

const INSTRUCAO_FOR := "Runa 1 (FOR): complete o laço para mostrar os números de 1 até quantidade (10)."
const INSTRUCAO_WHILE := "Runa 2 (WHILE): complete o laço para contar de 1 até 10 usando a variável runa."
const INFO_TITULO := "INFORMAÇÕES ÚTEIS"

# ---------------------------------------------------------------------------
# ESTÉTICA — PALETA (PRETO + VERMELHO ARCANO + BRANCO)
# ---------------------------------------------------------------------------
const COR_FUNDO := Color("000000")
const COR_PAINEL := Color("0c0607")
const COR_BOTAO := Color("110708")
const COR_TERMINAL := Color("070304")

const COR_VERMELHO_MUITO_ESCURO := Color("1c0709")
const COR_VERMELHO_ESCURO := Color("330b10")
const COR_VERMELHO_APAGADO := Color("6b2c32")
const COR_VERMELHO_FORTE := Color("7d1119")
const COR_VERMELHO_MEDIO := Color("a3202b")
const COR_VERMELHO := Color("d42b37")
const COR_VERMELHO_INTENSO := Color("f0323f")
const COR_VERMELHO_VIVO := Color("ff4655")
const COR_VERMELHO_BRILHO := Color("ff9098")

const COR_TEXTO := Color("f5efef")
const COR_TEXTO_DESABILITADO := Color("84666a")

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
# NODES (todos acessados por nome único — "Access as Unique Name" na cena)
# ---------------------------------------------------------------------------
@onready var janela_puzzle: Panel = %JanelaPuzzle
@onready var barra_titulo: PanelContainer = %BarraTitulo
@onready var titulo: Label = %Titulo
@onready var indicador_desafio: Label = %IndicadorDesafio
@onready var chip_for: Label = %ChipFor
@onready var chip_while: Label = %ChipWhile

@onready var painel_informacoes: PanelContainer = %PainelInformacoes
@onready var titulo_informacoes: Label = %TituloInformacoes
@onready var texto_informacoes: RichTextLabel = %TextoInformacoes

@onready var painel_for: PanelContainer = %PainelFor
@onready var painel_while: PanelContainer = %PainelWhile
@onready var cabecalho_for: Label = %CabecalhoFor
@onready var cabecalho_while: Label = %CabecalhoWhile

@onready var slot_for_inicio: Button = %SlotForInicio
@onready var slot_for_condicao: Button = %SlotForCondicao
@onready var slot_for_incremento: Button = %SlotForIncremento
@onready var slot_while_condicao: Button = %SlotWhileCondicao
@onready var slot_while_incremento: Button = %SlotWhileIncremento

@onready var painel_opcoes: PanelContainer = %PainelOpcoes
@onready var titulo_opcoes: Label = %TituloOpcoes
@onready var opcoes_for: Container = %OpcoesFor
@onready var opcoes_while: Container = %OpcoesWhile

@onready var painel_feedback: PanelContainer = %PainelFeedback
@onready var texto_feedback: RichTextLabel = %TextoFeedback

@onready var painel_botoes: PanelContainer = %PainelBotoes
@onready var btn_dica: Button = %Dica
@onready var btn_limpar: Button = %Limpar
@onready var btn_testar: Button = %Testar
@onready var btn_executar: Button = %Executar

# ---------------------------------------------------------------------------
# ESTADO
# ---------------------------------------------------------------------------
# desafio -> { espaço -> Button do slot }
var _slots: Dictionary = {"FOR": {}, "WHILE": {}}
# desafio -> { espaço -> Node.name do bloco colocado ("" = vazio) }
var _estado: Dictionary = {"FOR": {}, "WHILE": {}}
# "FOR:Inicio" -> Button do bloco que está nesse espaço
var _opcao_no_slot: Dictionary = {}
# desafio -> quantas dicas já foram mostradas
var _nivel_dica: Dictionary = {"FOR": 0, "WHILE": 0}
var _resolvido: Dictionary = {"FOR": false, "WHILE": false}

var _desafio_ativo: String = "FOR"
var _puzzle_resolvido: bool = false

var _fonte_mono: SystemFont


func _ready() -> void:
	_slots["FOR"] = {
		"Inicio": slot_for_inicio,
		"Condicao": slot_for_condicao,
		"Incremento": slot_for_incremento,
	}
	_slots["WHILE"] = {
		"Condicao": slot_while_condicao,
		"Incremento": slot_while_incremento,
	}
	for desafio in _slots.keys():
		for nome_slot in _slots[desafio].keys():
			_estado[desafio][nome_slot] = ""

	_conectar_opcoes()
	_conectar_slots()
	_conectar_botoes()

	_aplicar_estetica()
	_mudar_desafio_ativo("FOR")
	_mostrar_saida(PackedStringArray([
		"> Bem-vindo à Fortaleza Arcana!",
		"",
		"Clique nos blocos de runa para preencher os espaços brilhantes do código.",
		"Clique em um espaço preenchido para retirar o bloco.",
		"Use Testar para verificar e Dica se precisar de ajuda.",
	]))


# ---------------------------------------------------------------------------
# CONEXÃO DE SINAIS
# ---------------------------------------------------------------------------
func _conectar_opcoes() -> void:
	_conectar_opcoes_de(opcoes_for, "FOR", BLOCOS_FOR)
	_conectar_opcoes_de(opcoes_while, "WHILE", BLOCOS_WHILE)


func _conectar_opcoes_de(container: Container, desafio: String, blocos: Dictionary) -> void:
	for filho in container.get_children():
		if not (filho is BaseButton):
			continue
		var opcao := filho as BaseButton
		if not blocos.has(str(opcao.name)):
			push_warning("Puzzle_Fortaleza: bloco '%s' não está em BLOCOS_%s." % [opcao.name, desafio])
			continue
		opcao.pressed.connect(_on_opcao_pressionada.bind(opcao, desafio))


func _conectar_slots() -> void:
	for desafio in _slots.keys():
		for nome_slot in _slots[desafio].keys():
			var slot: Button = _slots[desafio][nome_slot]
			slot.pressed.connect(_on_slot_pressionado.bind(nome_slot, desafio))


# Cada conexão é protegida por is_connected para evitar duplicidade caso o
# sinal já tenha sido ligado pelo editor.
func _conectar_botoes() -> void:
	if not btn_executar.pressed.is_connected(_on_executar_pressed):
		btn_executar.pressed.connect(_on_executar_pressed)
	if not btn_limpar.pressed.is_connected(_on_limpar_pressed):
		btn_limpar.pressed.connect(_on_limpar_pressed)
	if not btn_testar.pressed.is_connected(_on_testar_pressed):
		btn_testar.pressed.connect(_on_testar_pressed)
	if not btn_dica.pressed.is_connected(_on_dica_pressed):
		btn_dica.pressed.connect(_on_dica_pressed)


# ---------------------------------------------------------------------------
# DESAFIO ATIVO
# ---------------------------------------------------------------------------
func _mudar_desafio_ativo(desafio: String) -> void:
	_desafio_ativo = desafio
	var eh_for: bool = desafio == "FOR"

	titulo.text = INSTRUCAO_FOR if eh_for else INSTRUCAO_WHILE
	titulo_informacoes.text = INFO_TITULO
	painel_for.visible = eh_for
	painel_while.visible = not eh_for
	opcoes_for.visible = eh_for
	opcoes_while.visible = not eh_for

	texto_informacoes.text = _montar_texto_informacoes(desafio)
	texto_informacoes.scroll_to_line(0)

	_atualizar_progresso()


func _atualizar_progresso() -> void:
	var concluidos: int = int(_resolvido["FOR"]) + int(_resolvido["WHILE"])
	indicador_desafio.text = "Progresso: %d de 2 desafios   |   Desafio atual: %s" % [concluidos, _desafio_ativo]
	_estilizar_chip(chip_for, "FOR", 1)
	_estilizar_chip(chip_while, "WHILE", 2)


# ---------------------------------------------------------------------------
# COLOCAR / REMOVER BLOCOS
# ---------------------------------------------------------------------------
func _on_opcao_pressionada(opcao: BaseButton, desafio: String) -> void:
	if desafio != _desafio_ativo or _esta_resolvido(desafio):
		return

	var nome_bloco: String = str(opcao.name)
	var nome_slot: String = _blocos(desafio).get(nome_bloco, "")
	if nome_slot == "":
		return

	var estado: Dictionary = _estado[desafio]
	if estado[nome_slot] != "":
		_mostrar_saida(PackedStringArray([
			"[!] O espaço \"%s\" já está ocupado." % NOMES_SLOT[nome_slot],
			"Clique nele para retirar o bloco antes de escolher outro.",
		]))
		return

	# Identificação interna = nome do Node (nunca o texto visível).
	estado[nome_slot] = nome_bloco
	_opcao_no_slot["%s:%s" % [desafio, nome_slot]] = opcao

	var slot: Button = _slots[desafio][nome_slot]
	slot.text = (opcao as Button).text
	_aplicar_estilo_slot_preenchido(slot)

	opcao.visible = false
	opcao.disabled = true


func _on_slot_pressionado(nome_slot: String, desafio: String) -> void:
	if desafio != _desafio_ativo or _esta_resolvido(desafio):
		return

	var estado: Dictionary = _estado[desafio]
	if estado[nome_slot] == "":
		return  # slot vazio: clicar não faz nada

	var chave: String = "%s:%s" % [desafio, nome_slot]
	var opcao: BaseButton = _opcao_no_slot.get(chave, null)

	estado[nome_slot] = ""
	_resetar_slot(desafio, nome_slot)

	if opcao != null:
		opcao.visible = true
		opcao.disabled = false
		_opcao_no_slot.erase(chave)


func _resetar_slot(desafio: String, nome_slot: String) -> void:
	var slot: Button = _slots[desafio][nome_slot]
	slot.text = PLACEHOLDER
	_aplicar_estilo_slot_vazio(slot)


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _blocos(desafio: String) -> Dictionary:
	return BLOCOS_FOR if desafio == "FOR" else BLOCOS_WHILE


func _resposta(desafio: String) -> Dictionary:
	return RESPOSTA_FOR if desafio == "FOR" else RESPOSTA_WHILE


func _ordem_slots(desafio: String) -> Array[String]:
	return SLOTS_FOR if desafio == "FOR" else SLOTS_WHILE


func _esta_resolvido(desafio: String) -> bool:
	return _resolvido[desafio]


# ---------------------------------------------------------------------------
# VALIDAÇÃO — "vazio", "incorreto" ou "correto" (nunca usa eval)
# ---------------------------------------------------------------------------
func _validar(desafio: String) -> String:
	var estado: Dictionary = _estado[desafio]
	var resposta: Dictionary = _resposta(desafio)

	for nome_slot in resposta.keys():
		if estado.get(nome_slot, "") == "":
			return "vazio"

	var tudo_correto: bool = true
	for nome_slot in resposta.keys():
		if str(estado[nome_slot]) != str(resposta[nome_slot]):
			tudo_correto = false
			if DEBUG_VALIDACAO:
				print("[Puzzle_Fortaleza][%s] espaço '%s': esperado '%s', recebido '%s'" % [desafio, nome_slot, resposta[nome_slot], estado[nome_slot]])

	return "correto" if tudo_correto else "incorreto"


func _contar_corretos(desafio: String) -> int:
	var estado: Dictionary = _estado[desafio]
	var resposta: Dictionary = _resposta(desafio)
	var total: int = 0
	for nome_slot in resposta.keys():
		if str(estado[nome_slot]) == str(resposta[nome_slot]):
			total += 1
	return total


# ---------------------------------------------------------------------------
# DICAS PROGRESSIVAS
# ---------------------------------------------------------------------------
func _proxima_dica(desafio: String) -> PackedStringArray:
	var dicas: Array[String] = DICAS_FOR if desafio == "FOR" else DICAS_WHILE
	var nivel: int = mini(int(_nivel_dica[desafio]) + 1, dicas.size())
	_nivel_dica[desafio] = nivel
	return PackedStringArray(["DICA %d/%d:" % [nivel, dicas.size()], dicas[nivel - 1]])


func _on_dica_pressed() -> void:
	var desafio: String = _desafio_ativo
	var linhas := PackedStringArray()
	linhas.append("> Pedindo uma dica para o desafio %s..." % desafio)
	linhas.append("")
	if _esta_resolvido(desafio):
		linhas.append("[OK] Este desafio já foi concluído.")
	else:
		linhas.append_array(_proxima_dica(desafio))
	_mostrar_saida(linhas)


# ---------------------------------------------------------------------------
# SIMULAÇÃO DE SAÍDA (nunca executa o laço de verdade — só representa)
# ---------------------------------------------------------------------------
func _simular(desafio: String) -> PackedStringArray:
	var numeros := PackedStringArray()
	for i in range(1, 11):
		numeros.append(str(i))

	var linhas := PackedStringArray()
	linhas.append("Saída: " + " ".join(numeros))
	if desafio == "FOR":
		linhas.append("O contador i foi de 1 até quantidade (10), aumentando 1 a cada volta.")
	else:
		linhas.append("runa aumentou a cada volta até passar de 10; aí a condição ficou falsa e o laço terminou.")
	return linhas


# ---------------------------------------------------------------------------
# TESTAR / EXECUTAR
# ---------------------------------------------------------------------------
# Testar nunca conclui o puzzle.
func _on_testar_pressed() -> void:
	_verificar_desafio_ativo(false)


# Executar conclui o puzzle somente quando FOR e WHILE estão resolvidos.
func _on_executar_pressed() -> void:
	_verificar_desafio_ativo(true)


func _verificar_desafio_ativo(modo_executar: bool) -> void:
	var desafio: String = _desafio_ativo
	var linhas := PackedStringArray()
	linhas.append("> %s desafio %s..." % ["Executando" if modo_executar else "Testando", desafio])
	linhas.append("")

	var recem_resolvido: bool = false

	if not _esta_resolvido(desafio):
		var resultado: String = _validar(desafio)
		if resultado == "vazio":
			linhas.append("[!] Existem espaços vazios.")
			linhas.append("[!] Preencha todos os espaços do desafio %s." % desafio)
			_mostrar_saida(linhas)
			return
		if resultado == "incorreto":
			_adicionar_feedback_erro(desafio, linhas)
			_mostrar_saida(linhas)
			return

		_resolvido[desafio] = true
		recem_resolvido = true
		_atualizar_progresso()
		linhas.append("[OK] Desafio %s concluído!" % desafio)
		linhas.append("")
		linhas.append_array(_simular(desafio))
		linhas.append("")

	if desafio == "FOR":
		# O FOR resolvido nunca finaliza o puzzle: só libera o WHILE.
		linhas.append("[!] Próximo desafio: WHILE.")
		_mudar_desafio_ativo("WHILE")
		_mostrar_saida(linhas)
		return

	# Desafio WHILE resolvido (agora ou antes). O FOR já está resolvido, pois
	# o WHILE só fica ativo depois dele.
	if not recem_resolvido:
		linhas.append("[OK] Desafio WHILE já concluído.")

	if modo_executar:
		_finalizar_puzzle(linhas)
	else:
		linhas.append("INFO: clique em Executar para confirmar a finalização do puzzle.")
		_mostrar_saida(linhas)


func _adicionar_feedback_erro(desafio: String, linhas: PackedStringArray) -> void:
	var estado: Dictionary = _estado[desafio]
	var resposta: Dictionary = _resposta(desafio)
	var total: int = resposta.size()

	linhas.append("[X] O desafio %s ainda não está correto." % desafio)
	linhas.append("[!] Espaços certos: %d de %d." % [_contar_corretos(desafio), total])
	linhas.append("")

	for nome_slot in _ordem_slots(desafio):
		if str(estado[nome_slot]) != str(resposta[nome_slot]):
			var padrao: String = "Revise o espaço: %s." % NOMES_SLOT[nome_slot]
			linhas.append("[X] " + str(MENSAGENS_ERRO.get(str(estado[nome_slot]), padrao)))

	linhas.append("")
	linhas.append_array(_proxima_dica(desafio))


# Conclui o puzzle uma única vez.
func _finalizar_puzzle(linhas: PackedStringArray) -> void:
	if _puzzle_resolvido:
		linhas.append("[OK] O puzzle já foi concluído.")
		_mostrar_saida(linhas)
		return

	_puzzle_resolvido = true

	linhas.append("[OK] Desafio FOR concluído!")
	linhas.append("[OK] Desafio WHILE concluído!")
	linhas.append("")
	linhas.append("[OK] PUZZLE CONCLUÍDO!")
	linhas.append("INFO: você dominou os laços FOR e WHILE.")
	_mostrar_saida(linhas)

	# O puzzle NÃO troca de fase: só avisa. Quem escuta o sinal decide o resto.
	desafio_concluido.emit()


# ---------------------------------------------------------------------------
# LIMPAR (apenas o desafio ativo; nunca desfaz um desafio concluído)
# ---------------------------------------------------------------------------
func _on_limpar_pressed() -> void:
	var desafio: String = _desafio_ativo
	var linhas := PackedStringArray()
	linhas.append("> Limpando desafio %s..." % desafio)
	linhas.append("")

	if _esta_resolvido(desafio):
		linhas.append("[!] O desafio %s já foi concluído e não pode ser limpo." % desafio)
		_mostrar_saida(linhas)
		return

	for nome_slot in _slots[desafio].keys():
		var chave: String = "%s:%s" % [desafio, nome_slot]
		var opcao: BaseButton = _opcao_no_slot.get(chave, null)
		if opcao != null:
			opcao.visible = true
			opcao.disabled = false
			_opcao_no_slot.erase(chave)
		_estado[desafio][nome_slot] = ""
		_resetar_slot(desafio, nome_slot)

	linhas.append("[OK] Desafio %s limpo." % desafio)
	linhas.append("[INFO] Os blocos foram devolvidos ao painel de runas.")
	_mostrar_saida(linhas)


# ---------------------------------------------------------------------------
# TEXTOS
# ---------------------------------------------------------------------------
func _mostrar_saida(linhas: PackedStringArray) -> void:
	texto_feedback.text = "\n".join(linhas)
	texto_feedback.scroll_to_line(0)


func _montar_texto_informacoes(desafio: String) -> String:
	var linhas := PackedStringArray()
	if desafio == "FOR":
		linhas.append("Repetir é fazer a mesma ação várias vezes sem escrever o código várias vezes.")
		linhas.append("")
		linhas.append("O laço FOR é ótimo quando você já sabe quantas vezes quer repetir.")
		linhas.append("")
		linhas.append("Estrutura:")
		linhas.append("for (início; condição; passo) {")
		linhas.append("    // código repetido")
		linhas.append("}")
		linhas.append("")
		linhas.append("• início: onde o contador começa.")
		linhas.append("• condição: o laço continua enquanto ela for verdadeira.")
		linhas.append("• passo: como o contador muda a cada volta.")
		linhas.append("")
		linhas.append("Já preparamos a variável quantidade (vale 10). O console.log(i) mostra na tela o valor atual do contador i.")
		linhas.append("")
		linhas.append("Objetivo: mostrar os números de 1 até quantidade.")
		linhas.append("")
		linhas.append("Preencha os 3 espaços brilhantes. Travou? Clique em Dica.")
	else:
		linhas.append("O laço WHILE repete uma ação enquanto uma condição for verdadeira.")
		linhas.append("")
		linhas.append("Estrutura:")
		linhas.append("while (condição) {")
		linhas.append("    // código repetido")
		linhas.append("}")
		linhas.append("")
		linhas.append("• Antes de cada volta, o computador confere a condição.")
		linhas.append("• Se for verdadeira, o código roda de novo.")
		linhas.append("• Se for falsa, o laço termina.")
		linhas.append("")
		linhas.append("Diferença para o FOR: aqui o contador não fica dentro dos parênteses. Você cria a variável antes e a altera DENTRO do laço.")
		linhas.append("")
		linhas.append("Já preparamos let runa = 1; e o console.log(runa).")
		linhas.append("")
		linhas.append("Objetivo: contar de 1 até 10 com runa.")
		linhas.append("")
		linhas.append("Preencha os 2 espaços brilhantes. Travou? Clique em Dica.")
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

	_fonte_mono = SystemFont.new()
	_fonte_mono.font_names = ["Consolas", "Courier New", "monospace"]

	_aplicar_estilo_textos_recursivo(self)

	# Janela e painéis
	janela_puzzle.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, COR_VERMELHO_MEDIO, 3, 0))
	barra_titulo.add_theme_stylebox_override("panel", _caixa(COR_FUNDO, COR_VERMELHO_VIVO, 3, 12, -1, -1, 12, 6))
	titulo.add_theme_color_override("font_color", COR_VERMELHO_BRILHO)
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_outline_color", COR_VERMELHO_FORTE)
	titulo.add_theme_constant_override("outline_size", 2)

	for painel in [painel_informacoes, painel_opcoes, painel_botoes]:
		painel.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_VERMELHO_MEDIO, 2, 6, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL))
	painel_feedback.add_theme_stylebox_override("panel", _caixa(COR_TERMINAL, COR_VERMELHO_APAGADO, 2, 0, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL, RAIO_TERMINAL))

	# Painéis de código (o desafio visível ganha destaque)
	painel_for.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_VERMELHO_VIVO, 2, 8, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL))
	painel_while.add_theme_stylebox_override("panel", _caixa(COR_PAINEL, COR_VERMELHO_VIVO, 2, 8, -1, -1, MARGEM_H_PAINEL, MARGEM_V_PAINEL))

	# Cabeçalhos
	for cabecalho in [cabecalho_for, cabecalho_while, titulo_informacoes, titulo_opcoes]:
		cabecalho.add_theme_color_override("font_color", COR_VERMELHO_BRILHO)
		cabecalho.add_theme_font_size_override("font_size", 16)
	indicador_desafio.add_theme_font_size_override("font_size", 15)

	# Textos de leitura (RichTextLabel com rolagem própria)
	_configurar_rich_text(texto_informacoes)
	_configurar_rich_text(texto_feedback)

	# Código: fonte monoespaçada em linhas fixas e slots
	_aplicar_fonte_codigo(painel_for)
	_aplicar_fonte_codigo(painel_while)

	# Opções (blocos de runa)
	for container in [opcoes_for, opcoes_while]:
		for filho in container.get_children():
			if filho is Button:
				var botao := filho as Button
				_estilizar_botao_padrao(botao, RAIO_OPCAO)
				botao.add_theme_font_override("font", _fonte_mono)
				botao.add_theme_font_size_override("font_size", TAMANHO_FONTE_BOTAO)

	# Slots começam vazios e destacados
	for desafio in _slots.keys():
		for nome_slot in _slots[desafio].keys():
			_aplicar_estilo_slot_vazio(_slots[desafio][nome_slot])

	# Botões de ação
	_estilizar_botao_padrao(btn_testar)
	_estilizar_botao_padrao(btn_dica)
	_estilizar_botao_executar(btn_executar)
	_estilizar_botao_limpar(btn_limpar)
	for botao in [btn_testar, btn_dica, btn_executar, btn_limpar]:
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
	if (no is Label or no is Button) and no != cabecalho_for and no != cabecalho_while:
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
	barra.add_theme_stylebox_override("grabber", _caixa_simples(COR_VERMELHO_FORTE))
	barra.add_theme_stylebox_override("grabber_highlight", _caixa_simples(COR_VERMELHO))
	barra.add_theme_stylebox_override("grabber_pressed", _caixa_simples(COR_VERMELHO_VIVO))


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


func _caixa_foco(raio: int = RAIO_BORDA) -> StyleBoxFlat:
	var sb := _caixa(Color(0, 0, 0, 0), COR_VERMELHO_INTENSO, 2, 0, -1, -1, -1, -1, raio)
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
	var normal := _caixa(COR_BOTAO, COR_VERMELHO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 2, 8, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO, raio)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(raio), disabled, COR_TEXTO)


func _estilizar_botao_executar(botao: Button) -> void:
	var normal := _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_VIVO, 3, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 3, 12, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


func _estilizar_botao_limpar(botao: Button) -> void:
	var normal := _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_APAGADO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_MEDIO, 2, 0, 4, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO, 2, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var disabled := _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(botao, normal, hover, pressed, _caixa_foco(), disabled, COR_TEXTO)


# ---------------------------------------------------------------------------
# SLOTS
# Vazio: fundo avermelhado escuro, borda viva e brilho (destaca "preencha aqui").
# Preenchido: fundo preto, borda vermelha e texto vermelho-claro.
# ---------------------------------------------------------------------------
func _aplicar_estilo_slot_vazio(slot: Button) -> void:
	var normal := _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_VIVO, 2, 8, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 2, 10, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, hover, _caixa_foco(), normal, COR_TEXTO)


func _aplicar_estilo_slot_preenchido(slot: Button) -> void:
	var normal := _caixa(COR_FUNDO, COR_VERMELHO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var hover := _caixa(COR_VERMELHO_ESCURO, COR_VERMELHO_BRILHO, 3, 6, 5, 4, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	var pressed := _caixa(COR_VERMELHO_FORTE, COR_VERMELHO_VIVO, 3, 0, -1, -1, MARGEM_H_BOTAO, MARGEM_V_BOTAO)
	_definir_estilos(slot, normal, hover, pressed, _caixa_foco(), normal, COR_VERMELHO_BRILHO)


# ---------------------------------------------------------------------------
# CHIPS DE PROGRESSO (pendente / atual / concluído)
# ---------------------------------------------------------------------------
func _estilizar_chip(chip: Label, desafio: String, numero: int) -> void:
	var caixa: StyleBoxFlat
	var cor_texto: Color

	if _resolvido[desafio]:
		chip.text = "%d  %s  [OK]" % [numero, desafio]
		caixa = _caixa(COR_VERMELHO_FORTE, COR_VERMELHO, 2, 0, -1, -1, 10, 3)
		cor_texto = COR_TEXTO
	elif desafio == _desafio_ativo:
		chip.text = "%d  %s  (atual)" % [numero, desafio]
		caixa = _caixa(COR_VERMELHO_MUITO_ESCURO, COR_VERMELHO_VIVO, 3, 10, -1, -1, 10, 3)
		cor_texto = COR_VERMELHO_BRILHO
	else:
		chip.text = "%d  %s" % [numero, desafio]
		caixa = _caixa(COR_FUNDO, COR_VERMELHO_APAGADO, 1, 0, -1, -1, 10, 3)
		cor_texto = COR_TEXTO_DESABILITADO

	chip.add_theme_stylebox_override("normal", caixa)
	chip.add_theme_color_override("font_color", cor_texto)
