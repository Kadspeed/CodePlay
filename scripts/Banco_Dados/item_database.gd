extends Node
## ItemDatabase — banco de dados central dos disquetes do jogo.
##
## Responsabilidade única: armazenar e fornecer os dados de cada disquete
## (nome, título, texto, ícone). Não controla HUD, Inventário, Player,
## GameManager, NPCs, Puzzle ou Terminal — apenas responde a consultas.
##
## Registrado como AutoLoad sob o nome "ItemDatabase", portanto é acessado
## globalmente sem get_node(), por exemplo:
##   ItemDatabase.get_item("disquete_azul")
##
## Compatível com Godot 4.6.


# ============================================================
# CONSTANTES
# ============================================================
#region Constantes

## Pasta onde ficam os ícones dos disquetes. Centralizada aqui apenas
## como referência de organização; os `preload()` abaixo já resolvem
## os caminhos completos em tempo de compilação.
const CAMINHO_ICONES: String = "res://Creativos/disquetes/"

#endregion


# ============================================================
# BANCO DE DADOS
# ============================================================
#region Banco de Dados

## Dictionary único contendo todos os disquetes cadastrados. A chave é
## o "nome" do disquete (identificador único, sem IDs numéricos); o
## valor é o Dictionary completo do item.
##
## Para adicionar um novo disquete no futuro, basta inserir uma nova
## entrada aqui — nenhuma função da API Pública precisa ser alterada.
var _itens: Dictionary = {
	"disquete_azul": {
		"nome": "disquete_azul",
		"titulo": "Variáveis",
		"texto": """SISTEMA DE ARQUIVOS // MÓDULO 01: VARIÁVEIS 
		O que é JavaScript?
		JavaScript (JS) é a linguagem de programação que dá vida, dinamismo e interatividade às páginas da web e jogos. Enquanto o HTML constrói a estrutura e o CSS define o visual, o JavaScript funciona como o "cérebro", processando dados e respondendo aos comandos do jogador.

		O que são Variáveis?
		Variáveis funcionam como "caixas etiquetadas" na memória do computador. Elas servem para armazenar informações que o código precisa consultar, calcular ou modificar ao longo da execução — como a pontuação do jogador, a quantidade de vida ou o nome de um item.

		Como declarar variáveis no JS
		No JavaScript moderno, existem duas palavras-chave principais para criar variáveis:

		let: Usado quando o valor guardado pode mudar durante a partida.

		const: Usado para definir uma constante, ou seja, um valor que nunca muda após ser atribuído.

		JavaScript
		// Exemplo de código:
		let pontos = 0;             // A pontuação altera no decorrer do jogo
		const nomeJogador = "Alex"; // O nome permanece fixo

		pontos = 10;                // Atualiza o valor de 'pontos' para 10
		Tipos Básicos de Dados
		Dentro dessas variáveis, você pode armazenar diferentes tipos de valores:

		Number: Números inteiros ou decimais (ex: let vida = 100;)

		String: Textos envolvidos por aspas (ex: let item = "Disquete";)

		Boolean: Valores lógicos de verdadeiro ou falso (ex: let portaAberta = false;)

		Estrutura de Declaração

		Palavra-chave: let ou const (indica a criação da variável).

		Nome da Variável: O identificador da caixa (convenção camelCase, ex: pontosAtuais).

		Operador de Atribuição: O sinal de igual (=), que insere o valor na variável.

		Valor: Os dados armazenados.""",
		"icone": preload("res://Creativos/disquetes/disc/disquete_azul.png"),
	},
	"disquete_vermelho": {
		"nome": "disquete_vermelho",
		"titulo": "If / Else",
		"texto": "Este disquete contém informações sobre estruturas condicionais: como tomar decisões dentro de um programa usando if e else.",
		"icone": preload("res://Creativos/disquetes/disc/disquete_vermelho.png"),
	},
	"disquete_verde": {
		"nome": "disquete_verde",
		"titulo": "Loops",
		"texto": "Este disquete contém informações sobre laços de repetição: como repetir ações várias vezes usando for e while.",
		"icone": preload("res://Creativos/disquetes/verde.png"),
	},
	"disquete_roxo": {
		"nome": "disquete_roxo",
		"titulo": "Funções",
		"texto": "Este disquete contém informações sobre funções: como organizar código em blocos reutilizáveis.",
		"icone": preload("res://Creativos/disquetes/roxo.png"),
	},
	"disquete_amarelo": {
		"nome": "disquete_amarelo",
		"titulo": "Arrays",
		"texto": "Este disquete contém informações sobre arrays: como armazenar e organizar listas de valores.",
		"icone": preload("res://Creativos/disquetes/amarelo.png"),
	},
	"disquete_laranja": {
		"nome": "disquete_laranja",
		"titulo": "Objetos",
		"texto": "Este disquete contém informações sobre objetos: como agrupar dados e comportamentos relacionados.",
		"icone": preload("res://Creativos/disquetes/laranja.png"),
	},
	"disquete_branco": {
		"nome": "disquete_branco",
		"titulo": "Classes",
		"texto": "Este disquete contém informações sobre classes: como criar modelos para gerar objetos com estrutura e comportamento em comum.",
		"icone": preload("res://Creativos/disquetes/branco.png"),
	},
}

#endregion


# ============================================================
# API PÚBLICA
# ============================================================
#region API Pública

## Retorna o Dictionary completo de um disquete.
## [param nome]: identificador único do disquete (ex.: "disquete_azul").
## [return]: Dictionary com "nome", "titulo", "texto" e "icone",
## ou {} (vazio) se o disquete não existir.
func get_item(nome: String) -> Dictionary:
	if not existe_item(nome):
		return {}
	return _itens[nome]


## Verifica se um disquete com o nome informado está cadastrado.
## [param nome]: identificador único do disquete.
## [return]: true se o disquete existir, false caso contrário.
func existe_item(nome: String) -> bool:
	return _itens.has(nome)


## Retorna apenas o título de um disquete.
## [param nome]: identificador único do disquete.
## [return]: título do disquete, ou "" (string vazia) se não existir.
func get_titulo(nome: String) -> String:
	if not existe_item(nome):
		return ""
	return _itens[nome]["titulo"]


## Retorna apenas o texto de um disquete.
## [param nome]: identificador único do disquete.
## [return]: texto do disquete, ou "" (string vazia) se não existir.
func get_texto(nome: String) -> String:
	if not existe_item(nome):
		return ""
	return _itens[nome]["texto"]


## Retorna apenas o ícone de um disquete.
## [param nome]: identificador único do disquete.
## [return]: Texture2D do disquete, ou null se não existir.
func get_icone(nome: String) -> Texture2D:
	if not existe_item(nome):
		return null
	return _itens[nome]["icone"]


## Retorna os nomes de todos os disquetes cadastrados.
## [return]: Array com todos os identificadores (ex.: ["disquete_azul", ...]).
func get_lista_itens() -> Array:
	return _itens.keys()


## Retorna a quantidade total de disquetes cadastrados.
## [return]: número de itens no banco de dados.
func get_quantidade() -> int:
	return _itens.size()

#endregion


# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================
#region Funções Auxiliares

# Reservado para utilitários internos futuros (ex.: validação de
# integridade do banco de dados, carregamento a partir de arquivo
# externo, etc.) sem misturar responsabilidades com a API Pública.

#endregion
