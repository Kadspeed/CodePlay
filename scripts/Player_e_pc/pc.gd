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


# ============================================================
# 3. VARIÁVEIS DE ESTADO
# ============================================================

## Referência ao GameManager, único responsável por saber a fase
## atual, o disquete necessário e o puzzle correspondente. O PC não
## guarda mais essas informações localmente — ele apenas consulta.
var game_manager: Node = null

## Referência ao Player, usada apenas para travar/destravar o
## processamento de input dele enquanto um puzzle com raiz Node2D
## está aberto (puzzles com raiz Control já bloqueiam input sozinhos
## via mouse_filter, então essa referência não é usada nesse caso).
var player_ref: Node = null

var jogador_proximo: bool = false

## Instância atual do puzzle aberto por este PC. null quando fechado.
var puzzle_atual: Node = null

## Guarda a fase para a qual o puzzle atualmente aberto pertence,
## para que o sinal puzzle_concluido seja emitido com o fase_id
## correto mesmo que a fase do GameManager já tenha mudado por
## algum outro motivo entre a abertura e a conclusão do puzzle.
var _fase_do_puzzle_aberto: int = -1


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

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "🔑 Pressione Q"

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if anim:
		anim.play("PC")

	print("✅ PC pronto! (consulta o GameManager em tempo real, sem configuração fixa por fase)")


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
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		jogador_proximo = false
		print("👋 Jogador saiu")
		if prompt_label:
			prompt_label.visible = false


# ============================================================
# 7. INTERAÇÃO (CONSULTA O GAMEMANAGER, VERIFICA DISQUETE E ABRE O PUZZLE)
# ============================================================

## Chamado quando o jogador pressiona Q próximo ao PC.
## 1. Se já existe um puzzle aberto, ignora.
## 2. Consulta o GameManager para saber a fase atual e o disquete necessário.
## 3. Verifica no InventoryManager se o jogador possui o disquete.
## 4. Sem o disquete: mostra aviso e NÃO emite `interagir`.
## 5. Com o disquete: emite `interagir`, consulta o puzzle da fase
##    atual no GameManager e o abre.
func _interagir() -> void:
	if _puzzle_esta_aberto():
		print("⚠️ PC: puzzle desta instância já está aberto.")
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
	if player_ref == null:
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
	if prompt_label:
		prompt_label.visible = visivel

func is_jogador_proximo() -> bool:
	return jogador_proximo
