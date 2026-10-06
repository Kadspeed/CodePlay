extends Node2D
## Script de rolamento automático de créditos (efeito "crawl" vertical).
## Anexar este script ao nó RAIZ da cena: "TelaFinal" (Node2D).
##
## Estrutura esperada na cena:
##   TelaFinal (Node2D)               <- este script
##     └── PainelCreditos (Panel)      <- deve ter "Clip Contents" = true no Inspector
##         └── Creditos (RichTextLabel)

# Sinal emitido quando o texto termina de rolar completamente (ou o jogador pula).
signal creditos_finalizados

# Velocidade de rolagem em pixels por segundo. Ajustável no Inspector.
@export var velocidade_rolamento: float = 50.0

# Quantas vezes a velocidade base é multiplicada enquanto o jogador segura "ui_accept".
@export var multiplicador_velocidade: float = 3.0

# Caminho (.tscn) da próxima cena a ser carregada automaticamente ao final dos créditos.
# Se deixado vazio, o script apenas emite o sinal "creditos_finalizados" e não troca de cena.
@export_file("*.tscn") var proxima_cena_path: String = ""

# Referências aos nós filhos (Control), obtidas pelo caminho relativo na cena.
# Ajuste os caminhos abaixo caso a hierarquia dos seus nós seja diferente.
@onready var painel: Control = $PainelCreditos
@onready var creditos: RichTextLabel = $PainelCreditos/Creditos

# Evita que o sinal "creditos_finalizados" seja emitido mais de uma vez.
var _ja_finalizou: bool = false


func _ready() -> void:
	# --- Configurações essenciais do RichTextLabel para o efeito funcionar ---
	creditos.bbcode_enabled = true               # Habilita a interpretação de tags BBCode
	creditos.fit_content = true                   # O nó cresce em altura conforme o conteúdo
	creditos.scroll_active = false                 # Desativa a rolagem interna (moveremos manualmente)
	creditos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Faz o texto ocupar toda a largura do painel, mas crescer livremente em altura
	creditos.custom_minimum_size.x = painel.size.x
	creditos.size.x = painel.size.x

	# Define o conteúdo formatado em BBCode
	creditos.text = _montar_texto_creditos()

	# Espera um frame para o motor calcular a altura real do texto após aplicar o BBCode
	await get_tree().process_frame

	# Posiciona o texto inicialmente FORA da tela, logo abaixo do painel
	creditos.position.x = 0
	creditos.position.y = painel.size.y


func _process(delta: float) -> void:
	if _ja_finalizou:
		return

	# --- Pular instantaneamente com ESC ("ui_cancel") ---
	if Input.is_action_just_pressed("ui_cancel"):
		_finalizar_creditos()
		return

	# --- Acelerar a rolagem enquanto "ui_accept" (Espaço/Enter) estiver pressionado ---
	var velocidade_atual: float = velocidade_rolamento
	if Input.is_action_pressed("ui_accept"):
		velocidade_atual *= multiplicador_velocidade

	# Move o texto para cima de forma suave e independente de FPS
	creditos.position.y -= velocidade_atual * delta

	# Verifica se o texto já ultrapassou completamente o topo do painel
	if creditos.position.y + creditos.size.y < 0:
		_finalizar_creditos()


func _finalizar_creditos() -> void:
	if _ja_finalizou:
		return
	_ja_finalizou = true
	creditos_finalizados.emit()

	# Se um caminho de cena válido foi definido no Inspector, troca de cena automaticamente
	if proxima_cena_path != "":
		get_tree().change_scene_to_file(proxima_cena_path)


func _montar_texto_creditos() -> String:
	# Texto formatado em BBCode: títulos centralizados, negrito, cores e tamanhos de fonte,
	# organizado como uma sequência de créditos cinematográfica.
	return """



[center][font_size=44][b]FIM[/b][/font_size][/center]

[center][font_size=30][b]CRÉDITOS[/b][/font_size][/center]

[center][font_size=16][color=#BDC3C7]UM PROJETO DESENVOLVIDO COM[/color][/font_size][/center]
[center][font_size=16][color=#BDC3C7]CRIATIVIDADE, DEDICAÇÃO E TECNOLOGIA[/color][/font_size][/center]



[center][i][color=#7F8C8D]Os créditos a seguir representam as pessoas, ferramentas e recursos
que tornaram esta experiência possível.[/color][/i][/center]

[center][i][color=#7F8C8D]Cada nome, cada ferramenta e cada linha de código
fazem parte de uma mesma jornada de criação.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]DIREÇÃO E DESENVOLVIMENTO[/b][/font_size][/center]

[center][font_size=20][b][color=#FFFFFF]Kadmiel da Silva Soares[/color][/b][/font_size][/center]
[center][color=#BDC3C7]Direção de Jogo e Desenvolvimento Geral[/color][/center]

[center][i][color=#7F8C8D]Responsável pela direção criativa, pelo desenvolvimento
e pela integração geral de todos os sistemas do jogo.[/color][/i][/center]

[center][i][color=#7F8C8D]Cada decisão de design, cada ajuste e cada etapa de construção
passaram por um mesmo processo de cuidado e dedicação.[/color][/i][/center]

[center][i][color=#7F8C8D]Um projeto nasce de ideias, mas só se torna realidade
através de esforço contínuo e atenção aos detalhes.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]EQUIPE DE DESENVOLVIMENTO[/b][/font_size][/center]

[center][font_size=20][b][color=#FFFFFF]Kadmiel da Silva Soares[/color][/b][/font_size][/center]
[center][color=#BDC3C7]Direção e Desenvolvimento Geral[/color][/center]



[center][font_size=20][b][color=#FFFFFF]Arthur Meira Gomes[/color][/b][/font_size][/center]
[center][color=#BDC3C7]Efeitos Sonoros (SFX), Design de Fases e Documentação[/color][/center]

[center][i][color=#7F8C8D]Um jogo é construído por camadas: ideias, testes, ajustes
e muita colaboração entre as partes envolvidas.[/color][/i][/center]

[center][i][color=#7F8C8D]O planejamento e a organização das tarefas foram parte essencial
para que cada elemento se encaixasse no todo.[/color][/i][/center]

[center][i][color=#7F8C8D]Momentos de teste, correção e revisão fizeram parte constante
do processo até a versão final do projeto.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=24][b]EFEITOS SONOROS[/b][/font_size][/center]
[center][color=#FFFFFF]Arthur Meira Gomes[/color][/center]

[center][i][color=#7F8C8D]O som dá vida aos momentos do jogo, reforçando emoções
e tornando cada cena mais marcante.[/color][/i][/center]



[center][font_size=24][b]DESIGN DE FASES[/b][/font_size][/center]
[center][color=#FFFFFF]Arthur Meira Gomes[/color][/center]

[center][i][color=#7F8C8D]O desenho cuidadoso das fases molda o ritmo da experiência
e o caminho percorrido pelo jogador.[/color][/i][/center]



[center][font_size=24][b]DOCUMENTAÇÃO DO PROJETO[/b][/font_size][/center]
[center][color=#FFFFFF]Arthur Meira Gomes[/color][/center]

[center][i][color=#7F8C8D]Registrar decisões e processos garante organização
e clareza durante toda a produção.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]AGRADECIMENTOS ESPECIAIS[/b][/font_size][/center]

[center][font_size=18][b][color=#FFFFFF]Lucio Moro[/color][/b][/font_size][/center]
[center][color=#BDC3C7]Professor Auxiliar[/color][/center]



[center][font_size=18][b][color=#FFFFFF]Renan Soprani[/color][/b][/font_size][/center]
[center][color=#BDC3C7]Professor Auxiliar[/color][/center]

[center][i][color=#7F8C8D]Nosso agradecimento aos professores auxiliares, pelo apoio,
pela orientação e pelo acompanhamento oferecidos ao longo do processo.[/color][/i][/center]

[center][i][color=#7F8C8D]O incentivo constante contribuiu para o amadurecimento
das ideias e para a conclusão deste projeto.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=28][b]AO JOGADOR[/b][/font_size][/center]

[center][color=#BDC3C7]Obrigado por dedicar o seu tempo a esta experiência.[/color][/center]

[center][color=#BDC3C7]É o jogador que dá sentido a tudo o que foi construído aqui.
Cada fase percorrida, cada desafio enfrentado e cada decisão tomada
fazem parte de uma jornada compartilhada entre quem cria e quem joga.[/color][/center]

[center][color=#BDC3C7]Os obstáculos superados ao longo do caminho não foram apenas
etapas do jogo, mas também parte da própria experiência vivida.[/color][/center]

[center][color=#BDC3C7]Você fez parte desta jornada.[/color][/center]

[center][i][color=#FFFFFF]E a experiência não termina aqui, ao chegar aos créditos —
ela continua em cada memória que ela deixou.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]SOBRE O DESENVOLVIMENTO[/b][/font_size][/center]

[center][i][color=#7F8C8D]Tudo começa com uma ideia, ainda simples e incerta.[/color][/i][/center]

[center][i][color=#7F8C8D]O planejamento transforma essa ideia em um caminho possível.[/color][/i][/center]

[center][i][color=#7F8C8D]A programação dá forma e movimento ao que antes era apenas conceito.[/color][/i][/center]

[center][i][color=#7F8C8D]A criação das fases desenha o ritmo e o desafio da experiência.[/color][/i][/center]

[center][i][color=#7F8C8D]Os testes revelam falhas, e os ajustes corrigem o rumo.[/color][/i][/center]

[center][i][color=#7F8C8D]Cada problema resolvido representa um novo aprendizado.[/color][/i][/center]

[center][i][color=#7F8C8D]A experimentação abre espaço para novas possibilidades.[/color][/i][/center]

[center][i][color=#7F8C8D]E assim, passo a passo, um jogo se torna realidade.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]TECNOLOGIAS E FERRAMENTAS[/b][/font_size][/center]

[center][font_size=20][b]MOTOR DE JOGO[/b][/font_size][/center]
[center][color=#FFFFFF]Godot Engine[/color][/center]
[center][i][color=#7F8C8D]Motor utilizado como base para toda a construção do jogo.[/color][/i][/center]



[center][font_size=20][b]LINGUAGEM DE PROGRAMAÇÃO[/b][/font_size][/center]
[center][color=#FFFFFF]GDScript[/color][/center]
[center][i][color=#7F8C8D]Linguagem utilizada na escrita da lógica e dos sistemas do jogo.[/color][/i][/center]



[center][font_size=20][b]INTELIGÊNCIA ARTIFICIAL E ASSISTÊNCIA[/b][/font_size][/center]

[center][color=#FFFFFF]Claude AI[/color][/center]
[center][i][color=#7F8C8D]Utilizado como auxílio no desenvolvimento dos scripts.[/color][/i][/center]

[center][color=#FFFFFF]ChatGPT[/color][/center]
[center][i][color=#7F8C8D]Utilizado para criação e refinamento dos prompts
utilizados para orientar o desenvolvimento dos scripts.[/color][/i][/center]

[center][i][color=#555555]As ferramentas de inteligência artificial foram utilizadas
como assistência durante o desenvolvimento, não como autoras do jogo.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]RECURSOS VISUAIS E ATIVOS[/b][/font_size][/center]

[center][color=#BDC3C7]Assets e sprites obtidos através do:[/color][/center]
[center][color=#FFFFFF]itch.io[/color][/center]

[center][i][color=#7F8C8D]Os recursos visuais ajudam a construir a identidade
e a atmosfera de todo o jogo.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]HOSPEDAGEM E CÓDIGO-FONTE[/b][/font_size][/center]

[center][color=#FFFFFF]GitHub[/color][/center]

[center][color=#BDC3C7]Este projeto está hospedado no GitHub.[/color][/center]
[center][color=#BDC3C7]O código-fonte está disponível no repositório oficial.[/color][/center]
[center][color=#BDC3C7]O jogo pode ser adquirido através do repositório oficial.[/color][/center]



[center]───────────────────[/center]



[center][font_size=26][b]FEITO COM[/b][/font_size][/center]

[center][color=#FFFFFF]Godot Engine[/color][/center]
[center][i][color=#7F8C8D]a base de tudo[/color][/i][/center]

[center][color=#FFFFFF]GDScript[/color][/center]
[center][i][color=#7F8C8D]a linguagem da lógica[/color][/i][/center]

[center][color=#FFFFFF]Claude AI[/color][/center]
[center][i][color=#7F8C8D]assistência no código[/color][/i][/center]

[center][color=#FFFFFF]ChatGPT[/color][/center]
[center][i][color=#7F8C8D]refinamento das ideias[/color][/i][/center]

[center][color=#FFFFFF]GitHub[/color][/center]
[center][i][color=#7F8C8D]guardião do código[/color][/i][/center]

[center][color=#FFFFFF]itch.io[/color][/center]
[center][i][color=#7F8C8D]origem dos recursos visuais[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=26][b]CADA DETALHE CONTA[/b][/font_size][/center]

[center][i][color=#7F8C8D]Ideias se transformam em projetos.[/color][/i][/center]

[center][i][color=#7F8C8D]Projetos se transformam em experiências.[/color][/i][/center]

[center][i][color=#7F8C8D]Cada desafio enfrentado durante o desenvolvimento
deixou um pouco de aprendizado para trás.[/color][/i][/center]

[center][i][color=#7F8C8D]Cada erro corrigido tornou o resultado final mais sólido.[/color][/i][/center]

[center][i][color=#7F8C8D]A dedicação e a criatividade caminharam juntas
até o momento em que este projeto pôde ser concluído.[/color][/i][/center]

[center][i][color=#7F8C8D]E, como em toda boa história, chegamos ao seu fim.[/color][/i][/center]



[center]───────────────────[/center]



[center][font_size=30][b]OBRIGADO[/b][/font_size][/center]

[center][color=#BDC3C7]A todos que, de alguma forma, tornaram este projeto possível —
o nosso mais sincero agradecimento.[/color][/center]

[center][color=#BDC3C7]E a você, que chegou até aqui:[/color][/center]

[center][font_size=22][b][color=#FFFFFF]OBRIGADO POR JOGAR![/color][/b][/font_size][/center]



[center][i][font_size=18][color=#FFFFFF]"A aventura termina aqui. A história, porém, continua com você."[/color][/font_size][/i][/center]



"""
