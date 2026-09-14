# scripts/game_manager.gd
extends Node2D

@onready var fase_atual_container: Node = $FaseAtual

var player: Node = null
var pc: Node = null
var spawn_point_atual: Marker2D = null
var _trocando_fase: bool = false

var fase_atual: int = 1

var fases := {
	1: {"titulo": "Floresta_Biotech", "cena": preload("res://cenas/Niveis/Floresta_Biotech.tscn"), "disquete": "disquete_azul", "puzzle": preload("res://cenas/Puzzles/puzzle_variaveis.tscn")},
	2: {"titulo": "Caverna_de_Cristal", "cena": preload("res://cenas/Niveis/caverna_de_cristal.tscn"), "disquete": "disquete_vermelho", "puzzle": preload("res://cenas/Puzzles/puzzle_caverna.tscn")},
	3: {"titulo": "Fortaleza_arcana", "cena": preload("res://cenas/Niveis/fortaleza_arcana.tscn"), "disquete": "disquete_verde", "puzzle": preload("res://cenas/Puzzles/puzzle_fortaleza.tscn")},
	4: {"titulo": "Cidade_Celestial", "cena": preload("res://cenas/Niveis/cidade_celestial.tscn"), "disquete": "disquete_roxo", "puzzle": preload("res://cenas/Puzzles/puzzle_cidade.tscn")},
	5: {"titulo": "Jardins_Mecanicos", "cena": preload("res://cenas/Niveis/jardins_mecanicos.tscn"), "disquete": "disquete_amarelo", "puzzle": preload("res://cenas/Puzzles/puzzle_jardins.tscn")},
	6: {"titulo": "Ruinas_Subterraneas", "cena": preload("res://cenas/Niveis/ruinas_subterraneas.tscn"), "disquete": "disquete_laranja", "puzzle": preload("res://cenas/Puzzles/puzzle_ruinas.tscn")},
	7: {"titulo": "Nucleo_do_Sistema", "cena": preload("res://cenas/Niveis/nucleo_do_sistema.tscn"), "disquete": "disquete_branco", "puzzle": preload("res://cenas/Puzzles/puzzle_nucleo.tscn")},
}


func _ready() -> void:
	add_to_group("game_manager")
	_resolver_player()

	if fase_atual_container == null:
		push_error("GameManager: nó 'FaseAtual' não encontrado na Cena_Principal.")
		return

	print("🚀 Carregando fase inicial: ", fases[fase_atual]["titulo"])
	_carregar_fase(fase_atual)


func _resolver_player() -> void:
	if has_node("../YSort/Player"):
		player = get_node("../YSort/Player")
	else:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("GameManager: Player não encontrado. Verifique 'CenaPrincipal/YSort/Player' ou o grupo 'player'.")


func _buscar_no_grupo_dentro(raiz: Node, grupo: String) -> Node:
	if raiz.is_in_group(grupo):
		return raiz
	for filho in raiz.get_children():
		var encontrado: Node = _buscar_no_grupo_dentro(filho, grupo)
		if encontrado:
			return encontrado
	return null


func _encontrar_spawn_point(raiz_fase: Node) -> Marker2D:
	var no: Node = raiz_fase.find_child("SpawnPoint", true, false)
	if no == null:
		push_warning("GameManager: nenhum nó 'SpawnPoint' encontrado na fase atual.")
		return null
	if no is Marker2D:
		return no
	push_warning("GameManager: nó 'SpawnPoint' encontrado, mas não é um Marker2D.")
	return null


func _encontrar_camera_limits(raiz_fase: Node) -> Node:
	var no: Node = raiz_fase.find_child("CameraLimits", true, false)
	if no == null:
		push_warning("GameManager: nenhum nó 'CameraLimits' encontrado na fase atual.")
	return no


## Conecta a fase recém-carregada: reposiciona o Player no SpawnPoint,
## aplica limites de câmera (se presentes e válidos) e conecta o sinal
## puzzle_concluido do PC. Nenhuma falha aqui deve gerar erro fatal —
## tudo que não for encontrado apenas gera push_warning, para que o
## fade de transição (revelar) sempre consiga rodar depois.
func _conectar_fase(raiz_fase: Node) -> void:
	pc = _buscar_no_grupo_dentro(raiz_fase, "pc")
	spawn_point_atual = _encontrar_spawn_point(raiz_fase)

	if player == null:
		push_warning("GameManager: Player não disponível para posicionar no SpawnPoint.")
	elif spawn_point_atual == null:
		push_warning("GameManager: fase atual não possui SpawnPoint; Player não foi reposicionado.")
	elif player.has_method("definir_ponto_respawn"):
		player.definir_ponto_respawn(spawn_point_atual.global_position)
	else:
		player.global_position = spawn_point_atual.global_position

	if player and player.has_method("resetar_vida"):
		player.resetar_vida()

	var limites_camera: Node = _encontrar_camera_limits(raiz_fase)
	if player and limites_camera and player.has_method("definir_limites_camera"):
		var possui_limites: bool = (
			"limite_esquerdo" in limites_camera
			and "limite_superior" in limites_camera
			and "limite_direito" in limites_camera
			and "limite_inferior" in limites_camera
		)
		if possui_limites:
			player.definir_limites_camera(
				limites_camera.limite_esquerdo,
				limites_camera.limite_superior,
				limites_camera.limite_direito,
				limites_camera.limite_inferior
			)
		else:
			push_warning("GameManager: 'CameraLimits' encontrado, mas sem as variáveis limite_esquerdo/superior/direito/inferior.")

	if pc == null:
		push_warning("GameManager: PC não encontrado na fase atual.")
		return

	if pc.has_signal("puzzle_concluido"):
		if not pc.puzzle_concluido.is_connected(_on_puzzle_concluido):
			pc.puzzle_concluido.connect(_on_puzzle_concluido)
			print("✅ GameManager: conectado ao PC da fase ", fase_atual)
	else:
		push_warning("GameManager: o PC desta fase não possui o sinal 'puzzle_concluido'.")


func _on_puzzle_concluido(fase_id: int) -> void:
	if _trocando_fase:
		return

	print("🧩 GameManager: puzzle concluído (fase ", fase_id, ")")

	if fase_id != fase_atual:
		push_warning("GameManager: puzzle_concluido recebido de uma fase diferente da atual (%d != %d)." % [fase_id, fase_atual])
		return

	if pc and pc.puzzle_concluido.is_connected(_on_puzzle_concluido):
		pc.puzzle_concluido.disconnect(_on_puzzle_concluido)

	_trocando_fase = true
	await get_tree().create_timer(1.5).timeout

	if fase_atual >= fases.size():
		_vitoria()
	else:
		avancar_para_proxima_fase()

	_trocando_fase = false


func avancar_para_proxima_fase() -> bool:
	if fase_atual >= fases.size():
		_vitoria()
		return false

	fase_atual += 1
	_carregar_fase(fase_atual)
	return true


## Troca a cena da fase atual pela cena de id `id`, com fade escurecendo
## antes da troca e clareando depois que a nova fase já está montada e
## conectada (Player reposicionado, câmera, sinal do PC, etc.).
func _carregar_fase(id: int) -> void:
	var fase_info: Dictionary = fases.get(id, {})
	var cena: PackedScene = fase_info.get("cena")

	if cena == null:
		push_warning("GameManager: a cena da fase %d ainda não foi configurada." % id)
		return

	await TransicaoTela.escurecer()

	for filho in fase_atual_container.get_children():
		filho.queue_free()

	var nova_fase: Node = cena.instantiate()
	fase_atual_container.add_child(nova_fase)

	print("🚀 Fase carregada: ", fase_info.get("titulo", "Fase %d" % id))

	_conectar_fase(nova_fase)

	# Sempre revela a tela, mesmo que _conectar_fase tenha tido problemas
	# (SpawnPoint ausente, PC ausente, CameraLimits incompleto, etc.) —
	# evita ficar preso na tela preta.
	await TransicaoTela.revelar()


func _vitoria() -> void:
	print("🏆 JOGO COMPLETO!")


func get_fase_atual_info() -> Dictionary:
	return fases[fase_atual]

func get_fase_atual() -> int:
	return fase_atual

func get_titulo_atual() -> String:
	return fases[fase_atual]["titulo"]

func get_disquete_necessario(id: int = -1) -> String:
	var alvo: int = id if id != -1 else fase_atual
	return fases.get(alvo, {}).get("disquete", "")

## Retorna a PackedScene do puzzle correspondente à fase informada
## (ou à fase atual, se `id` for omitido), para que o PC possa
## instanciá-la diretamente.
func get_puzzle_necessario(id: int = -1) -> PackedScene:
	var alvo: int = id if id != -1 else fase_atual
	return fases.get(alvo, {}).get("puzzle")

## Ponto único de consulta para o PC compartilhado entre as fases.
func get_info_pc() -> Dictionary:
	return {
		"fase": fase_atual,
		"disquete": get_disquete_necessario(),
		"puzzle": get_puzzle_necessario(),
	}

func get_progresso() -> Dictionary:
	return {
		"fase_atual": fase_atual,
		"titulo": get_titulo_atual(),
		"total_fases": fases.size(),
		"progresso_percentual": float(fase_atual - 1) / float(fases.size()) * 100.0
	}

func obter_spawn_point_atual() -> Marker2D:
	return spawn_point_atual

func obter_posicao_spawn_atual() -> Vector2:
	return spawn_point_atual.global_position if spawn_point_atual else Vector2.ZERO

func reiniciar_jogo() -> void:
	print("🔄 Reiniciando jogo...")
	fase_atual = 1
	player = null
	pc = null
	spawn_point_atual = null
	get_tree().reload_current_scene()
