# scripts/pc.gd
extends Area2D

# ============================================================
# 1. SINAIS
# ============================================================

## Emitido quando o jogador pressiona Q e a interação é válida
## (ou seja, ele possui o disquete necessário). Mantido por
## compatibilidade com quem já escuta este sinal (ex.: SFX, UI).
signal interagir()

## Emitido quando o puzzle desta fase é concluído. O GameManager
## deve conectar este sinal para decidir o avanço de fase — o PC
## não decide isso sozinho, apenas avisa.
signal puzzle_concluido(fase_id: int)


# ============================================================
# 2. NÓS
# ============================================================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $Label

## Som da fala do PC. Filho do PC chamado "Fala" (AudioStreamPlayer2D).
## Toca enquanto o PC fala e para quando a fala termina.
@onready var audio_fala: AudioStreamPlayer2D = get_node_or_null("Fala")


# ============================================================
# 3. CONFIGURAÇÕES, CONSTANTES E VARIÁVEIS DE ESTADO
# ============================================================

# --- Ajustável no Inspetor ---

@export_group("Aparência do Texto")

## Tamanho VISUAL final da fonte (em pixels do jogo).
## Vale tanto para "Pressione Q" quanto para as mensagens do PC.
## Mudar o valor atualiza o texto na hora.
@export_range(8, 64, 1) var tamanho_fonte: int = 24:
	set(valor):
		tamanho_fonte = valor
		_aplicar_tamanho_fonte()

@export_group("")

# --- Constantes ---

## Nome exato da animação do PC no AnimatedSprite2D.
## A animação só toca enquanto o PC está "falando" (veja _falar_mensagem);
## no resto do tempo ele fica parado no primeiro frame.
const NOME_ANIMACAO: String = "PC"

## true se o sprite do PC, SEM flip, está desenhado olhando para a DIREITA.
## Se na cena ele aparecer virado para o lado errado, troque para false.
const SPRITE_OLHA_PARA_DIREITA: bool = true

## Folga (em pixels) para o PC não ficar "tremendo" quando o player está
## quase exatamente alinhado com ele no eixo X.
const VIRAR_FOLGA_X: float = 4.0

## Texto padrão exibido quando o jogador chega perto do PC.
const TEXTO_PROMPT: String = "🔑 Pressione Q"

## Mensagem exibida quando o jogador tenta usar o PC sem o disquete.
## O %s é trocado pelo nome da cor do disquete (ex.: "Azul").
## O \n quebra a mensagem em duas linhas para ela não ficar larga demais.
const MSG_SEM_DISQUETE: String = "Pegue primeiro o Disquete %s\npara poder resolver o puzzle."

# --- Aparência do texto do PC (ajuste aqui, sem mexer na cena) ---

## Fator de nitidez: o texto é desenhado N vezes maior e reduzido via scale,
## evitando letras embaçadas quando o jogo é ampliado (zoom/stretch).
## Aumente (ex.: 6 ou 8) se ainda ficar borrado; use 1 para desativar.
const LABEL_SUPERAMOSTRAGEM: int = 4

## Cor do texto (dourado mágico).
const LABEL_COR_TEXTO: Color = Color("#F5C542")

## Cor do contorno (roxo bem escuro). Com a caixa escura atrás do texto,
## o contorno quase não é necessário; 0 = sem contorno.
const LABEL_COR_CONTORNO: Color = Color("#1B1033")

## Espessura VISUAL do contorno, em pixels do jogo.
const LABEL_TAMANHO_CONTORNO: int = 0

## Cor e deslocamento da sombra do texto.
const LABEL_COR_SOMBRA: Color = Color(0.0, 0.0, 0.0, 0.6)
const LABEL_DESLOCAMENTO_SOMBRA: int = 1

## Se true, centraliza o texto horizontalmente na origem deste nó
## (assume que o PC está centrado na origem da cena). Se o texto
## ficar deslocado para o lado, coloque false e posicione o Label no editor.
const LABEL_CENTRALIZAR: bool = true

# --- Caixa de fala (fundo, borda, sombra e posição) ---
# Todos os valores em pixels VISUAIS do jogo.

## Cor de fundo da caixa (roxo escuro, levemente translúcido).
const CAIXA_COR_FUNDO: Color = Color("#1B1033EB")

## Cor e espessura da borda (dourado, igual ao texto).
const CAIXA_COR_BORDA: Color = Color("#F5C542")
const CAIXA_LARGURA_BORDA: int = 2

## Arredondamento dos cantos.
const CAIXA_RAIO_CANTO: int = 6

## Espaço entre o texto e a borda da caixa.
const CAIXA_PADDING_HORIZONTAL: int = 8
const CAIXA_PADDING_VERTICAL: int = 5

## Sombra projetada da caixa (tamanho 0 desativa).
const CAIXA_COR_SOMBRA: Color = Color(0.0, 0.0, 0.0, 0.45)
const CAIXA_TAMANHO_SOMBRA: int = 3
const CAIXA_DESLOCAMENTO_SOMBRA_Y: int = 2

## A borda INFERIOR da caixa fica no Y em que você deixou o Label no editor;
## mensagens maiores crescem para cima. Use este valor para ajustar:
## negativo sobe a caixa, positivo desce.
const CAIXA_DESLOCAMENTO_Y: float = 0.0

## Ordem de desenho (Z Index absoluto) da caixa dentro do mundo do jogo.
## IMPORTANTE: o z_index só compara itens do MESMO CanvasLayer. O mundo
## fica na camada 0, os puzzles no PuzzleCanvasLayer (layer 10) e a HUD /
## JanelaDisquete em layer 100, então puzzles e JanelaDisquete sempre
## aparecem por cima da caixa. Dentro do mundo, 90 deixa a caixa na frente
## de tudo; se algo do mundo tiver z_index maior que 90, aumente este valor.
const CAIXA_Z_INDEX: int = 90

# --- Efeito de "fala" da mensagem ---

## Tempo, em segundos, para cada letra aparecer. Menor = mais rápido.
const SEGUNDOS_POR_LETRA: float = 0.035

## Tempo, em segundos, que a mensagem completa fica na tela antes de
## voltar ao texto "Pressione Q" (enquanto o jogador continuar perto).
const SEGUNDOS_MENSAGEM_PARADA: float = 3.0

# --- Variáveis de estado ---

## Referência ao GameManager, único responsável por saber a fase
## atual, o disquete necessário e o puzzle correspondente. O PC não
## guarda mais essas informações localmente — ele apenas consulta.
var game_manager: Node = null

## Referência ao Player. Usada para virar o PC na direção do player e
## para travar/destravar o processamento de input dele enquanto um puzzle
## com raiz Node2D está aberto (puzzles com raiz Control já bloqueiam
## input sozinhos via mouse_filter).
var player_ref: Node = null

var jogador_proximo: bool = false

## Instância atual do puzzle aberto por este PC. null quando fechado.
var puzzle_atual: Node = null

## Guarda a fase para a qual o puzzle atualmente aberto pertence,
## para que o sinal puzzle_concluido seja emitido com o fase_id
## correto mesmo que a fase do GameManager já tenha mudado por
## algum outro motivo entre a abertura e a conclusão do puzzle.
var _fase_do_puzzle_aberto: int = -1

## Tween da mensagem falada (guardado para poder cancelá-lo).
var _tween_mensagem: Tween = null

## Y (na posição do nó) onde fica a borda inferior da caixa de fala.
## Calculado em _estilizar_label() a partir da posição do Label na cena.
var _y_ancora_caixa: float = 0.0


# ============================================================
# 4. INICIALIZAÇÃO
# ============================================================

func _ready():
	add_to_group("interactive_pc")
	add_to_group("pc")

	game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		push_error("PC: GameManager não encontrado (grupo 'game_manager'). O PC não poderá funcionar.")

	player_ref = get_tree().get_first_node_in_group("player")

	if audio_fala == null:
		push_warning("PC: nó 'Fala' (AudioStreamPlayer2D) não encontrado. O PC vai falar sem som.")

	_estilizar_label()
	_esconder_texto()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# O PC começa parado no primeiro frame; a animação só toca quando ele fala.
	if anim:
		anim.animation = NOME_ANIMACAO
		_parar_animacao_pc()

	_virar_para_o_player()

	print("✅ PC pronto! (fonte: ", tamanho_fonte, ")")


func _process(_delta: float) -> void:
	_virar_para_o_player()


# ============================================================
# 4.1 DIREÇÃO DO PC (SEMPRE VIRADO PARA O PLAYER)
# ============================================================

## Vira o sprite do PC para o lado em que o player está (só esquerda/direita),
## o tempo todo — não só quando o player está perto. Usa flip_h do
## AnimatedSprite2D, então o Label/caixa de fala não é espelhado.
func _virar_para_o_player() -> void:
	if anim == null:
		return

	# O Player pode ainda não existir no _ready() ou ter sido recriado
	# (troca de fase/respawn), então a referência é buscada de novo se preciso.
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if player_ref == null:
			return

	var diferenca_x: float = player_ref.global_position.x - global_position.x
	if absf(diferenca_x) <= VIRAR_FOLGA_X:
		return  # quase alinhado: mantém a direção atual

	var player_na_direita: bool = diferenca_x > 0.0
	anim.flip_h = (player_na_direita != SPRITE_OLHA_PARA_DIREITA)


# ============================================================
# 5. INPUT
# ============================================================

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if Input.is_action_just_pressed("interagir_pc"):
			if jogador_proximo:
				_interagir()


# ============================================================
# 6. DETECÇÃO DE JOGADOR
# ============================================================

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		jogador_proximo = true
		print("🎮 Jogador detectado!")
		_mostrar_prompt()

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		jogador_proximo = false
		print("👋 Jogador saiu")
		_esconder_texto()


# ============================================================
# 7. INTERAÇÃO (CONSULTA O GAMEMANAGER, VERIFICA DISQUETE E ABRE O PUZZLE)
# ============================================================

## Chamado quando o jogador pressiona Q próximo ao PC.
## 1. Se já existe um puzzle aberto, ignora.
## 1.1. Se o Player está em corrida automática (transição de fase), ignora.
## 2. Consulta o GameManager para saber a fase atual e o disquete necessário.
## 3. Verifica no InventoryManager se o jogador possui o disquete.
## 4. Sem o disquete: o PC "fala" uma mensagem pedindo para pegar o
##    disquete primeiro (texto aparecendo letra por letra, com a
##    animação e o som do PC) e NÃO emite `interagir`.
## 5. Com o disquete: emite `interagir`, consulta o puzzle da fase
##    atual no GameManager e o abre.
func _interagir() -> void:
	if _puzzle_esta_aberto():
		print("⚠️ PC: puzzle desta instância já está aberto.")
		return

	# Não reabre o puzzle se o Player estiver em corrida automática (transição de fase).
	if player_ref != null and is_instance_valid(player_ref) \
			and player_ref.has_method("esta_em_corrida_automatica") \
			and player_ref.esta_em_corrida_automatica():
		return

	if game_manager == null:
		push_warning("PC: GameManager indisponível; não é possível verificar a fase atual.")
		return

	var fase_atual: int = game_manager.get_fase_atual()
	var disquete_necessario: String = game_manager.get_disquete_necessario()

	print("🖥️ PC: Interação detectada! (Tecla Q) — Fase atual: ", fase_atual)

	if not InventoryManager.verificar_item(disquete_necessario):
		var nome_amigavel: String = _obter_nome_amigavel(disquete_necessario)
		print("⚠️ Você precisa do disquete %s primeiro!" % nome_amigavel)
		_falar_mensagem(MSG_SEM_DISQUETE % nome_amigavel.capitalize())
		return

	interagir.emit()
	_abrir_puzzle(fase_atual)


## Converte "disquete_azul" em "azul", "disquete_vermelho" em
## "vermelho", etc., para montar a mensagem de aviso automaticamente
## sem precisar escrever um texto manual por fase.
func _obter_nome_amigavel(nome_item: String) -> String:
	return nome_item.replace("disquete_", "").replace("_", " ")


# ============================================================
# 8. GERENCIAMENTO DO PUZZLE
# ============================================================

func _puzzle_esta_aberto() -> bool:
	return puzzle_atual != null and is_instance_valid(puzzle_atual)


## Obtém o CanvasLayer dedicado ao puzzle, criando-o se necessário.
## IMPORTANTE: NÃO reaproveita qualquer CanvasLayer existente na cena.
## A versão anterior pegava "o primeiro CanvasLayer filho da cena
## atual" — e esse primeiro CanvasLayer era, por acaso, a própria
## HUD (hud.gd também extends CanvasLayer). Isso fazia o puzzle
## nascer DENTRO da HUD, junto do Inventario e da JanelaDisquete,
## e com z_index = 1000 ele bloqueava o clique nos slots.
## Agora o puzzle sempre vai para um CanvasLayer próprio, identificado
## pelo nome "PuzzleCanvasLayer", com layer menor que o da HUD (que
## a JanelaDisquete eleva para 50 em tempo de execução), garantindo
## que o Inventario continue clicável com o puzzle aberto.
func _obter_canvas_layer() -> CanvasLayer:
	var current_scene = get_tree().current_scene
	if current_scene:
		var existente: Node = current_scene.find_child("PuzzleCanvasLayer", true, false)
		if existente and existente is CanvasLayer:
			return existente

	var novo_canvas_layer := CanvasLayer.new()
	novo_canvas_layer.name = "PuzzleCanvasLayer"
	novo_canvas_layer.layer = 10  # abaixo do layer 50 forçado na HUD
	current_scene.add_child(novo_canvas_layer)
	return novo_canvas_layer


## Abre o puzzle correspondente à fase atual, obtendo a cena
## diretamente do GameManager (nada de puzzle_scene fixo no Inspector).
func _abrir_puzzle(fase_atual: int) -> void:
	var puzzle_scene: PackedScene = game_manager.get_puzzle_necessario()

	if not puzzle_scene:
		push_warning("PC: GameManager não retornou uma puzzle_scene válida para a fase %d." % fase_atual)
		return

	print("🚪 PC: abrindo puzzle da fase ", fase_atual, "...")

	puzzle_atual = puzzle_scene.instantiate()

	if not puzzle_atual:
		push_warning("PC: falha ao instanciar o puzzle da fase %d." % fase_atual)
		return

	_fase_do_puzzle_aberto = fase_atual

	var canvas_layer = _obter_canvas_layer()
	canvas_layer.add_child(puzzle_atual)

	if puzzle_atual is Control:
		# 🔥 CORREÇÃO 1/2: só esticamos o puzzle para ocupar a tela inteira
		# se ele NÃO tiver um tamanho já definido na própria cena. Antes,
		# isso era feito incondicionalmente, sobrescrevendo qualquer
		# posição/tamanho configurado manualmente no editor para o puzzle
		# — fazendo-o sempre aparecer esticado/centralizado, mesmo quando
		# você já tinha posicionado ele do jeito que queria.
		if puzzle_atual.size == Vector2.ZERO:
			var viewport = get_viewport()
			if viewport:
				var viewport_size = viewport.get_visible_rect().size

				puzzle_atual.position = Vector2.ZERO
				puzzle_atual.size = viewport_size

				puzzle_atual.anchor_left = 0.0
				puzzle_atual.anchor_top = 0.0
				puzzle_atual.anchor_right = 1.0
				puzzle_atual.anchor_bottom = 1.0
				puzzle_atual.offset_left = 0
				puzzle_atual.offset_top = 0
				puzzle_atual.offset_right = 0
				puzzle_atual.offset_bottom = 0

		# 🔥 CORREÇÃO 2/2: o root do puzzle usa MOUSE_FILTER_IGNORE em vez
		# de MOUSE_FILTER_STOP. Antes, como o root cobria a tela inteira
		# e "parava" o clique nela, QUALQUER clique em QUALQUER ponto da
		# tela (inclusive nos slots do Inventário na HUD, que fica numa
		# CanvasLayer abaixo desta) era engolido pelo puzzle antes de
		# chegar à HUD. Com IGNORE, o próprio root deixa de participar da
		# detecção de mouse, então cliques em áreas vazias do puzzle
		# atravessam até o que está por trás (HUD/Inventário/JanelaDisquete).
		# Isso NÃO afeta os botões/campos internos do puzzle: Button,
		# LineEdit, TextEdit etc. já usam MOUSE_FILTER_STOP por padrão e
		# continuam capturando clique normalmente dentro de si mesmos.
		puzzle_atual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		# Puzzles com raiz Node2D (ex.: Puzzle_Caverna) não têm
		# mouse_filter para travar input automaticamente, então o
		# PC trava manualmente o processamento de input do Player
		# enquanto o puzzle estiver aberto, evitando que teclas/cliques
		# vazem para o mundo do jogo atrás do puzzle.
		_travar_input_player(true)

	if puzzle_atual.has_signal("desafio_concluido"):
		if not puzzle_atual.desafio_concluido.is_connected(_on_puzzle_concluido):
			puzzle_atual.desafio_concluido.connect(_on_puzzle_concluido)
	else:
		push_warning("PC (fase %d): o puzzle instanciado não possui o sinal 'desafio_concluido'." % fase_atual)
		puzzle_atual.queue_free()
		puzzle_atual = null
		_fase_do_puzzle_aberto = -1
		_travar_input_player(false)
		return

	# Fallback opcional, caso o puzzle use um sinal alternativo.
	# NOTA: como puzzle_variaveis.gd emite tanto 'desafio_concluido'
	# quanto 'puzzle_completado' na mesma resolução, os dois sinais
	# ficam conectados ao MESMO handler (_on_puzzle_concluido). O
	# guard dentro de _on_puzzle_concluido() garante que ele só
	# execute uma vez por conclusão, mesmo recebendo os dois sinais.
	if puzzle_atual.has_signal("puzzle_completado"):
		if not puzzle_atual.puzzle_completado.is_connected(_on_puzzle_concluido):
			puzzle_atual.puzzle_completado.connect(_on_puzzle_concluido)

	print("✅ PC: puzzle da fase ", fase_atual, " aberto com sucesso.")


## Ativa/desativa o processamento de input do Player. Usado apenas
## para puzzles com raiz Node2D (sem bloqueio de input nativo).
func _travar_input_player(travar: bool) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")

	if player_ref == null:
		return

	player_ref.set_process_input(not travar)
	player_ref.set_process_unhandled_input(not travar)


func _fechar_puzzle() -> void:
	if puzzle_atual and is_instance_valid(puzzle_atual):
		if puzzle_atual.has_signal("desafio_concluido"):
			if puzzle_atual.desafio_concluido.is_connected(_on_puzzle_concluido):
				puzzle_atual.desafio_concluido.disconnect(_on_puzzle_concluido)

		if puzzle_atual.has_signal("puzzle_completado"):
			if puzzle_atual.puzzle_completado.is_connected(_on_puzzle_concluido):
				puzzle_atual.puzzle_completado.disconnect(_on_puzzle_concluido)

		if not (puzzle_atual is Control):
			_travar_input_player(false)

		puzzle_atual.queue_free()

	puzzle_atual = null


## Chamado quando o puzzle emite `desafio_concluido` (ou `puzzle_completado`).
## O PC fecha o puzzle e avisa o GameManager que a fase para a qual o
## puzzle foi aberto está concluída, sem decidir sozinho o que acontece
## a seguir.
func _on_puzzle_concluido() -> void:
	if puzzle_atual == null:
		return

	var fase_concluida: int = _fase_do_puzzle_aberto
	print("🧩 PC: puzzle da fase ", fase_concluida, " concluído!")
	_fechar_puzzle()
	_fase_do_puzzle_aberto = -1
	puzzle_concluido.emit(fase_concluida)


# ============================================================
# 9. FUNÇÕES PÚBLICAS AUXILIARES
# ============================================================

func mostrar_prompt(visivel: bool) -> void:
	if visivel:
		_mostrar_prompt()
	else:
		_esconder_texto()

func is_jogador_proximo() -> bool:
	return jogador_proximo


# ============================================================
# 10. TEXTO DO PC (ESTILO, CAIXA, PROMPT E MENSAGEM FALADA)
# ============================================================

## Aplica o visual do texto e da caixa de fala (fonte, cores, contorno,
## sombra, caixa estilizada, camada de desenho, tamanho e alinhamento).
## Chamado uma vez no _ready().
##
## O texto e a caixa são desenhados em tamanho maior (LABEL_SUPERAMOSTRAGEM)
## e o Label é reduzido com scale, o que mantém o tamanho visual e deixa
## as letras e as bordas nítidas.
func _estilizar_label() -> void:
	if prompt_label == null:
		return

	var label: Label = prompt_label
	var s: int = maxi(LABEL_SUPERAMOSTRAGEM, 1)

	label.text = TEXTO_PROMPT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Um Label Settings salvo na cena ignoraria o tamanho definido aqui.
	label.label_settings = null
	label.add_theme_font_size_override("font_size", tamanho_fonte * s)
	label.add_theme_color_override("font_color", LABEL_COR_TEXTO)
	label.add_theme_color_override("font_outline_color", LABEL_COR_CONTORNO)
	label.add_theme_constant_override("outline_size", LABEL_TAMANHO_CONTORNO * s)
	label.add_theme_color_override("font_shadow_color", LABEL_COR_SOMBRA)
	label.add_theme_constant_override("shadow_offset_x", LABEL_DESLOCAMENTO_SOMBRA * s)
	label.add_theme_constant_override("shadow_offset_y", LABEL_DESLOCAMENTO_SOMBRA * s)

	# Caixa de fala: o Label desenha este StyleBox atrás do texto e já
	# inclui o padding no tamanho mínimo, então a caixa acompanha o texto.
	label.add_theme_stylebox_override("normal", _criar_estilo_caixa(s))

	# A caixa não deve capturar cliques do mouse.
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Fica na frente de tudo no mundo do jogo (veja CAIXA_Z_INDEX).
	label.z_as_relative = false
	label.z_index = CAIXA_Z_INDEX

	label.pivot_offset = Vector2.ZERO
	label.scale = Vector2.ONE / float(s)

	# Guarda onde fica a borda inferior da caixa (posição do Label na cena).
	_y_ancora_caixa = roundf(label.position.y) + CAIXA_DESLOCAMENTO_Y
	_reposicionar_label()


## Aplica o tamanho da fonte do Inspetor ao Label. Chamada pelo setter de
## `tamanho_fonte`, então qualquer mudança de valor atualiza o texto na hora.
func _aplicar_tamanho_fonte() -> void:
	if prompt_label == null:
		return

	var s: int = maxi(LABEL_SUPERAMOSTRAGEM, 1)
	prompt_label.label_settings = null
	prompt_label.add_theme_font_size_override("font_size", tamanho_fonte * s)
	_reposicionar_label()


## Monta o StyleBoxFlat da caixa de fala. Todas as medidas são multiplicadas
## por `s` (superamostragem), pois o Label é reduzido depois com scale.
func _criar_estilo_caixa(s: int) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()

	caixa.bg_color = CAIXA_COR_FUNDO
	caixa.border_color = CAIXA_COR_BORDA
	caixa.set_border_width_all(CAIXA_LARGURA_BORDA * s)
	caixa.set_corner_radius_all(CAIXA_RAIO_CANTO * s)
	caixa.anti_aliasing = true

	# Quando content_margin é definido, ele substitui a largura da borda no
	# cálculo do tamanho mínimo; por isso a borda é somada ao padding.
	caixa.content_margin_left = (CAIXA_PADDING_HORIZONTAL + CAIXA_LARGURA_BORDA) * s
	caixa.content_margin_right = (CAIXA_PADDING_HORIZONTAL + CAIXA_LARGURA_BORDA) * s
	caixa.content_margin_top = (CAIXA_PADDING_VERTICAL + CAIXA_LARGURA_BORDA) * s
	caixa.content_margin_bottom = (CAIXA_PADDING_VERTICAL + CAIXA_LARGURA_BORDA) * s

	caixa.shadow_color = CAIXA_COR_SOMBRA
	caixa.shadow_size = CAIXA_TAMANHO_SOMBRA * s
	caixa.shadow_offset = Vector2(0.0, CAIXA_DESLOCAMENTO_SOMBRA_Y * s)

	return caixa


## Encolhe a caixa do Label ao tamanho do texto atual e a reposiciona:
## centralizada na horizontal e com a borda inferior fixa em _y_ancora_caixa
## (mensagens maiores crescem para cima, sem cobrir o PC).
## Deve ser chamada sempre que o texto mudar. Usa o texto COMPLETO, então
## durante o efeito de digitação a caixa não muda de tamanho.
func _reposicionar_label() -> void:
	if prompt_label == null:
		return

	var label: Label = prompt_label
	label.size = Vector2.ZERO

	# get_minimum_size() já reflete o texto/fonte/caixa atuais; label.size só
	# seria atualizado no próximo frame. Arredonda para não cair em
	# posição fracionária (causa de letras borradas).
	var tamanho_visual: Vector2 = label.get_minimum_size() * label.scale

	if LABEL_CENTRALIZAR:
		label.position.x = roundf(-tamanho_visual.x / 2.0)

	label.position.y = roundf(_y_ancora_caixa - tamanho_visual.y)


## Mostra o texto padrão "Pressione Q" (sem efeito de digitação, sem animação e sem som).
func _mostrar_prompt() -> void:
	if prompt_label == null:
		return

	_cancelar_tween_mensagem()
	_parar_animacao_pc()
	prompt_label.text = TEXTO_PROMPT
	prompt_label.visible_characters = -1
	_reposicionar_label()
	prompt_label.visible = true


## Esconde o texto, cancela qualquer mensagem em andamento e para a animação e o som.
func _esconder_texto() -> void:
	_cancelar_tween_mensagem()
	_parar_animacao_pc()
	if prompt_label == null:
		return

	prompt_label.visible = false
	prompt_label.visible_characters = -1
	prompt_label.text = TEXTO_PROMPT
	_reposicionar_label()


## Faz o PC "falar": toca a animação e o som e mostra a mensagem letra por letra.
## A animação e o som duram enquanto as letras aparecem e param quando a
## mensagem termina de ser digitada. Depois a mensagem fica parada por
## SEGUNDOS_MENSAGEM_PARADA e então o texto volta para "Pressione Q"
## (se o jogador ainda estiver perto).
func _falar_mensagem(texto: String) -> void:
	if prompt_label == null:
		return

	_cancelar_tween_mensagem()

	prompt_label.text = texto
	_reposicionar_label()
	prompt_label.visible_characters = 0
	prompt_label.visible = true

	_tocar_animacao_pc()

	var total: int = prompt_label.get_total_character_count()
	_tween_mensagem = create_tween()
	_tween_mensagem.tween_property(
		prompt_label, "visible_characters", total, total * SEGUNDOS_POR_LETRA
	)
	_tween_mensagem.tween_callback(_parar_animacao_pc)
	_tween_mensagem.tween_interval(SEGUNDOS_MENSAGEM_PARADA)
	_tween_mensagem.tween_callback(_restaurar_prompt_apos_mensagem)


## Chamada ao fim da mensagem: volta ao prompt se o jogador ainda está perto.
func _restaurar_prompt_apos_mensagem() -> void:
	if jogador_proximo:
		_mostrar_prompt()
	else:
		_esconder_texto()


## Inicia a animação do PC do primeiro frame e o som da fala
## (só é chamada quando ele fala).
func _tocar_animacao_pc() -> void:
	_parar_animacao_pc()

	if anim:
		anim.play(NOME_ANIMACAO)

	if audio_fala:
		audio_fala.play()


## Para a animação (deixando o PC no primeiro frame, estado "parado")
## e para o som da fala.
func _parar_animacao_pc() -> void:
	if anim:
		anim.stop()
		anim.frame = 0

	if audio_fala and audio_fala.playing:
		audio_fala.stop()


func _cancelar_tween_mensagem() -> void:
	if _tween_mensagem and _tween_mensagem.is_valid():
		_tween_mensagem.kill()
	_tween_mensagem = null
