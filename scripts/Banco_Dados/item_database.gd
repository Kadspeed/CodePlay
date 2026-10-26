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
		"texto":"""O que você precisa saber

Variáveis são espaços na memória usados para guardar informações. Cada variável tem um nome e armazena um valor que pode ser utilizado pelo programa.

Exemplo:
let energia = 100;
let nome = "Explorador";

let permite criar uma variável cujo valor pode mudar. Números são escritos sem aspas; textos usam aspas.

Pista para o puzzle: observe o tipo de informação que precisa ser guardada e escolha um nome que represente essa informação.""",
		"icone": preload("res://Creativos/disquetes/disquete_azul.png"),
	},
	"disquete_vermelho": {
		"nome": "disquete_vermelho",
		"titulo": "If / Else",
		"texto": """"O que você precisa saber

Condicionais permitem que o programa tome decisões. O if executa um bloco quando uma condição é verdadeira; o else define o que acontece quando ela é falsa.

Exemplo:
if (energia > 50) {
    // liberar o portal
} else {
    // manter o portal fechado
}

O símbolo > significa "maior que". Já === verifica se dois valores são iguais.

Pista para o puzzle: identifique a condição que precisa ser verdadeira e confira o operador de comparação antes de escolher a resposta.""",
		"icone": preload("res://Creativos/disquetes/disquete_vermelho.png"),
	},
	"disquete_verde": {
		"nome": "disquete_verde",
		"titulo": "Loops",
		"texto": """"O que você precisa saber

Laços repetem instruções sem precisar escrever o mesmo código várias vezes.

O for é útil quando você controla a repetição por um contador. O while repete enquanto uma condição for verdadeira.

Exemplo com for:
for (let i = 0; i < 3; i++) {
    // executar uma ação
}

Exemplo com while:
while (energia > 0) {
    // continuar a ação
}

No primeiro exemplo, i++ aumenta o contador em uma unidade. No segundo, a condição precisa eventualmente se tornar falsa para que o laço termine.

Pista para o puzzle: se o desafio envolve uma quantidade definida de repetições, pense em for. Se depende de uma condição que continua mudando, considere while.""",
		"icone": preload("res://Creativos/disquetes/disquete_verde.png"),
	},
	"disquete_roxo": {
		"nome": "disquete_roxo",
		"titulo": "Funções",
		"texto": """O que você precisa saber

Uma função reúne instruções que podem ser executadas sempre que necessário. Ela pode receber parâmetros e devolver um resultado.

Exemplo:
function somar(a, b) {
    return a + b;
}

function declara a função, a e b são parâmetros e return devolve o resultado.

Para executar a função:
somar(2, 3);

Pista para o puzzle: identifique onde a função começa, quais informações ela recebe e qual instrução precisa executar.""",
		"icone": preload("res://Creativos/disquetes/disquete_roxo.png"),
	},
	"disquete_amarelo": {
		"nome": "disquete_amarelo",
		"titulo": "Arrays",
		"texto": """O que você precisa saber

Um array guarda vários valores em uma única estrutura, mantendo-os em uma ordem definida.

Exemplo:
let ferramentas = ["chave", "martelo", "serrote"];

Cada elemento tem um índice, que começa em 0. Assim, ferramentas[0] acessa "chave".

Você também pode consultar quantos elementos existem usando .length.

Pista para o puzzle: quando precisar guardar uma coleção de itens, procure uma estrutura com colchetes []. Lembre-se de que o primeiro elemento está no índice zero.""",
		"icone": preload("res://Creativos/disquetes/disquete_amarelo.png"),
	},
	"disquete_laranja": {
		"nome": "disquete_laranja",
		"titulo": "Objetos",
		"texto": """O que você precisa saber

Objetos agrupam informações relacionadas em propriedades, organizadas por pares de chave e valor.

Exemplo:
let porta = {
    material: "ferro",
    aberta: false
};

Nesse exemplo, material e aberta são propriedades. Você pode acessar uma propriedade usando a notação de ponto, como porta.material.

Pista para o puzzle: se várias informações pertencem à mesma entidade, pense em um objeto. Cada propriedade precisa de uma chave e de um valor correspondente.""",
		"icone": preload("res://Creativos/disquetes/disquete_laranja.png"),
	},
	"disquete_branco": {
		"nome": "disquete_branco",
		"titulo": "Classes",
		"texto":"""O que você precisa saber

Uma classe funciona como um modelo para criar objetos. Ela define características e comportamentos que esses objetos podem ter.

Exemplo:
class Nave {
    constructor(modelo) {
        this.modelo = modelo;
    }
}

class declara a classe. constructor inicializa o objeto, recebendo os parâmetros necessários. A palavra-chave this referencia o objeto atual.

Em this.modelo = modelo, o lado esquerdo indica a propriedade do objeto e o lado direito indica o valor recebido pelo parâmetro.

Pista para o puzzle: observe a relação entre os parâmetros do construtor e as propriedades após this. O nome de uma propriedade e o nome de um parâmetro podem ser iguais, mas representam papéis diferentes.""",
		"icone": preload("res://Creativos/disquetes/disquete_branco.png"),
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
