# scripts/game_manager.gd
extends Node2D

@onready var fase_atual_container: Node = $FaseAtual

var player: Node = null
var pc: Node = null
var spawn_point_atual: Marker2D = null
var _trocando_fase: bool = false
## true quando o Player foi travado para a troca de fase (Círculo Mágico);
## destravado em _conectar_fase se nenhuma corrida de entrada o liberar antes.
var _destravar_player_apos_troca: bool = false
## Círculo de ENTRADA da fase recém-carregada (Jardins Mecânicos). Preenchido em
## _conectar_fase e consumido em _carregar_fase, depois do fade de revelar.
var _circulo_entrada_pendente: Node = null

var fase_atual: int = 1

# --- ALTERAÇÃO: referência para a cena final (créditos), usada em _vitoria() ---
# Caminho (e não preload): um preload com caminho inexistente é erro de PARSE e derruba
# o script inteiro (nenhuma fase carregava no export). Carregado sob demanda em _vitoria().
# AJUSTE este caminho para a capitalização/pasta EXATA de Tela_Final.tscn no projeto.
const CENA_FINAL_CAMINHO: String = "res://cenas/Tela_Final.tscn"
const CENA_GAME_OVER: String = "uid://biekyj47ggbqp"

var _game_over_em_andamento: bool = false

# "corrida_saida" / "corrida_entrada": se true, o Player corre automaticamente
# ao sair desta fase (após concluir o puzzle) / ao entrar nela.
# "saida_circulo": a fase termina revelando o Círculo Mágico.
# "entrada_circulo": a fase começa com o Círculo Mágico (Player surge dele).
var fases := {
	1: {"titulo": "Floresta_Biotech", "cena": preload("res://cenas/Niveis/Floresta_Biotech.tscn"), "disquete": "disquete_azul", "puzzle": preload("res://cenas/Puzzles/puzzle_variaveis.tscn"), "corrida_saida": true, "corrida_entrada": true},
	2: {"titulo": "Caverna_de_Cristal", "cena": preload("res://cenas/Niveis/caverna_de_cristal.tscn"), "disquete": "disquete_vermelho", "puzzle": preload("res://cenas/Puzzles/puzzle_caverna.tscn"), "corrida_saida": true, "corrida_entrada": true},
	3: {"titulo": "Fortaleza_arcana", "cena": preload("res://cenas/Niveis/fortaleza_arcana.tscn"), "disquete": "disquete_verde", "puzzle": preload("res://cenas/Puzzles/puzzle_fortaleza.tscn"), "corrida_saida": true, "corrida_entrada": true},
	4: {"titulo": "Cidade_Celestial", "cena": preload("res://cenas/Niveis/cidade_celestial.tscn"), "disquete": "disquete_roxo", "puzzle": preload("res://cenas/Puzzles/puzzle_cidade.tscn"), "corrida_saida": false, "corrida_entrada": true, "saida_circulo": true},
	5: {"titulo": "Jardins_Mecanicos", "cena": preload("res://cenas/Niveis/jardins_mecanicos.tscn"), "disquete": "disquete_amarelo", "puzzle": preload("res://cenas/Puzzles/puzzle_jardins.tscn"), "corrida_saida": true, "corrida_entrada": true, "entrada_circulo": true},
	6: {"titulo": "Ruinas_Subterraneas", "cena": preload("res://cenas/Niveis/ruinas_subterraneas.tscn"), "disquete": "disquete_laranja", "puzzle": preload("res://cenas/Puzzles/puzzle_ruinas.tscn"), "corrida_saida": true, "corrida_entrada": true},
	7: {"titulo": "Nucleo_do_Sistema", "cena": preload("res://cenas/Niveis/nucleo_do_sistema.tscn"), "disquete": "disquete_branco", "puzzle": preload("res://cenas/Puzzles/puzzle_nucleo.tscn"), "corrida_saida": false, "corrida_entrada": false},
}


func _ready() -> void:
	add_to_group("game_manager")
	_resolver_player()
	if player != null and player.has_signal("player_morreu"):
		var callback: Callable = Callable(self, "_on_player_morreu")
		if not player.is_connected("player_morreu", callback):
			player.connect("player_morreu", callback)

	if fase_atual_container == null:
		push_error("GameManager: nó 'FaseAtual' não encontrado na Cena_Principal.")
		return

	# Um reinício após Game Over retoma a fase em que o Player morreu.
	var fase_pendente: int = EstadoJogo.consumir_fase_reinicio()

	if fase_pendente > 0:
		fase_atual = clampi(fase_pendente, 1, fases.size())
		print("🔄 Reiniciando a fase em que o Player morreu: ", fase_atual)
	else:
		fase_atual = 1

	print("🚀 Carregando fase inicial: ", fases[fase_atual]["titulo"])
	_carregar_fase(fase_atual)


func _on_player_morreu() -> void:
	if _game_over_em_andamento:
		return

	_game_over_em_andamento = true
	EstadoJogo.preparar_reinicio(fase_atual)

	if is_instance_valid(player) and player.has_method("bloquear_respawn_game_over"):
		player.bloquear_respawn_game_over()

	print("💀 GameManager: Game Over na fase ", fase_atual)

	# A SceneTree e o estado da fase são preservados antes da troca de cena.
	var arvore: SceneTree = get_tree()
	await TransicaoTela.escurecer()

	if not is_inside_tree():
		return

	var erro: Error = arvore.change_scene_to_file(CENA_GAME_OVER)
	if erro != OK:
		push_error("GameManager: falha ao abrir a tela Game Over (erro %d)." % erro)
		arvore.process_frame.connect(Callable(TransicaoTela, "revelar"), CONNECT_ONE_SHOT)
		return

	arvore.process_frame.connect(Callable(TransicaoTela, "revelar"), CONNECT_ONE_SHOT)


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

	# Entrada por Círculo Mágico (Jardins Mecânicos) tem prioridade sobre a corrida
	# de entrada: o Player fica escondido e travado, e a sequência só começa em
	# _carregar_fase, depois que a tela clareia. Caso contrário, segue o fluxo normal.
	if not _preparar_entrada_circulo(raiz_fase):
		# Corrida de entrada (ou encerramento da corrida, se a fase não tiver).
		# Fica aqui, depois do spawn e dos limites e antes do "return" do PC ausente,
		# para ser sempre avaliada.
		_aplicar_corrida_entrada()
		_destravar_player_se_necessario()

	if pc == null:
		push_warning("GameManager: PC não encontrado na fase atual.")
		return

	if pc.has_signal("puzzle_concluido"):
		if not pc.puzzle_concluido.is_connected(_on_puzzle_concluido):
			pc.puzzle_concluido.connect(_on_puzzle_concluido)
			print("✅ GameManager: conectado ao PC da fase ", fase_atual)
	else:
		push_warning("GameManager: o PC desta fase não possui o sinal 'puzzle_concluido'.")


# ============================================================
# CORRIDA AUTOMÁTICA (a lógica em si fica no Player)
# ============================================================

## Consulta se a fase `id` tem a corrida configurada ("corrida_saida" / "corrida_entrada").
func _fase_tem_corrida(id: int, chave: String) -> bool:
	return bool(fases.get(id, {}).get(chave, false))


func _encerrar_corrida_player() -> void:
	if is_instance_valid(player) and player.has_method("encerrar_corrida_automatica"):
		player.encerrar_corrida_automatica()


## Chamada por _conectar_fase: inicia a corrida de entrada se a fase tiver essa
## configuração; caso contrário, garante que o Player não continue em corrida.
func _aplicar_corrida_entrada() -> void:
	if not is_instance_valid(player):
		return
	if _fase_tem_corrida(fase_atual, "corrida_entrada") and player.has_method("iniciar_corrida_entrada"):
		player.iniciar_corrida_entrada()
	else:
		_encerrar_corrida_player()


## Chamada pelo Player ao renascer no SpawnPoint (queda ou morte): repete a
## corrida de entrada da fase atual, se ela estiver habilitada.
## (O círculo de entrada NÃO se repete: ele só aparece ao entrar na fase.)
func reaplicar_corrida_entrada() -> void:
	_aplicar_corrida_entrada()


# ============================================================
# CÍRCULO MÁGICO — ENTRADA (início dos Jardins Mecânicos)
# ============================================================

## Se a fase atual usa entrada por círculo e o círculo existe na cena, esconde e
## trava o Player (ele fica no SpawnPoint, em cima do círculo) e guarda o círculo
## para ser acionado depois do fade de revelar. Retorna false se não se aplica.
func _preparar_entrada_circulo(raiz_fase: Node) -> bool:
	_circulo_entrada_pendente = null

	if not bool(fases.get(fase_atual, {}).get("entrada_circulo", false)):
		return false
	if not is_instance_valid(player):
		return false

	var circulo: Node = _buscar_no_grupo_dentro(raiz_fase, "circulo_magico")
	if circulo == null or not circulo.has_method("executar_entrada"):
		push_warning("GameManager: fase %d usa entrada por Círculo Mágico, mas ele não foi encontrado; seguindo com a entrada normal." % fase_atual)
		return false

	_circulo_entrada_pendente = circulo

	# Garante que nenhuma corrida anterior continue ativa.
	_encerrar_corrida_player()

	# Player escondido e travado até o círculo aparecer.
	player.visible = false
	if player.has_method("abrir_puzzle"):
		player.abrir_puzzle()  # mesmo mecanismo de trava usado na saída
	_destravar_player_apos_troca = false
	return true


## Roda depois do fade de revelar: o círculo aparece e conduz a sequência.
func _iniciar_entrada_circulo() -> void:
	var circulo: Node = _circulo_entrada_pendente
	_circulo_entrada_pendente = null

	if circulo == null or not is_instance_valid(circulo):
		_on_player_surgir_do_circulo()
		return

	circulo.executar_entrada(Callable(self, "_on_player_surgir_do_circulo"))


## Chamada pelo círculo no momento em que o Player deve surgir.
func _on_player_surgir_do_circulo() -> void:
	if not is_instance_valid(player):
		return

	player.visible = true
	if player.has_method("desbloquear"):
		player.desbloquear()

	# Agora sim a corrida de entrada normal da fase (se configurada).
	_aplicar_corrida_entrada()


# ============================================================
# CÍRCULO MÁGICO — SAÍDA (Cidade Celestial)
# ============================================================

## Procura o Círculo Mágico na fase atual (grupo "circulo_magico"), conecta o
## sinal dele e o revela. Retorna false se não encontrar (aí o fluxo normal segue).
func _revelar_circulo_magico() -> bool:
	var circulo: Node = _buscar_no_grupo_dentro(fase_atual_container, "circulo_magico")
	if circulo == null or not circulo.has_method("revelar") or not circulo.has_signal("jogador_alcancou"):
		return false

	if not circulo.jogador_alcancou.is_connected(_on_circulo_alcancado):
		circulo.jogador_alcancou.connect(_on_circulo_alcancado, CONNECT_ONE_SHOT)

	circulo.revelar()
	return true


## O Player chegou perto do círculo: trava o personagem durante o fade e
## avança para a próxima fase (mesmo fluxo e mesmo fade de sempre).
func _on_circulo_alcancado() -> void:
	if is_instance_valid(player) and player.has_method("abrir_puzzle"):
		player.abrir_puzzle()
		_destravar_player_apos_troca = true

	avancar_para_proxima_fase()
	_trocando_fase = false


## Devolve o controle ao Player depois da troca, a menos que a corrida de
## entrada da nova fase já esteja no comando (ela mesma devolve no fim).
func _destravar_player_se_necessario() -> void:
	if not _destravar_player_apos_troca:
		return
	_destravar_player_apos_troca = false

	if not is_instance_valid(player):
		return

	var em_corrida: bool = player.has_method("esta_em_corrida_automatica") and player.esta_em_corrida_automatica()
	if not em_corrida and player.has_method("desbloquear"):
		player.desbloquear()


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

	# Fases com saída por Círculo Mágico (Cidade Celestial): em vez de avançar
	# sozinho, revela o círculo e espera o Player chegar perto dele. A flag
	# _trocando_fase continua true até lá (evita conclusões duplicadas).
	if bool(fases.get(fase_atual, {}).get("saida_circulo", false)):
		if _revelar_circulo_magico():
			return
		push_warning("GameManager: fase %d usa saída por Círculo Mágico, mas ele não foi encontrado; avançando normalmente." % fase_atual)

	# Fases com corrida de saída: o Player corre até passar do limite direito da
	# câmera. O sinal também é emitido em caso de cancelamento (timeout, preso,
	# morte), então esta espera nunca trava. As demais fases mantêm a espera de 1,5 s.
	var corrida_iniciada: bool = false
	if _fase_tem_corrida(fase_atual, "corrida_saida") and is_instance_valid(player) and player.has_method("iniciar_corrida_saida"):
		corrida_iniciada = player.iniciar_corrida_saida()

	if corrida_iniciada:
		await player.corrida_automatica_finalizada
	else:
		await get_tree().create_timer(1.5).timeout

	if fase_atual >= fases.size():
		_encerrar_corrida_player()
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
		_destravar_player_se_necessario()
		_encerrar_corrida_player()
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

	# Entrada por Círculo Mágico: só começa depois que a tela já clareou.
	if _circulo_entrada_pendente != null:
		_iniciar_entrada_circulo()


# --- ALTERAÇÃO PRINCIPAL: _vitoria() carrega a cena final (Tela_Final.tscn) ---
# IMPORTANTE: change_scene_to_packed() remove a cena corrente (Mundo, onde este
# GameManager vive) da árvore IMEDIATAMENTE e a libera no fim do frame. Por isso,
# depois dessa chamada este nó NÃO está mais na árvore (get_tree() == null) e logo
# será destruído: nenhum código deste script pode continuar rodando depois dela.
# - A SceneTree é guardada ANTES da troca;
# - o "revelar" é entregue ao autoload TransicaoTela (que persiste entre cenas),
#   disparado no próximo frame, quando a Tela_Final já está na árvore.
func _vitoria() -> void:
	print("🏆 JOGO COMPLETO!")

	var arvore: SceneTree = get_tree()

	await TransicaoTela.escurecer()

	var cena_final: PackedScene = load(CENA_FINAL_CAMINHO) as PackedScene
	if cena_final == null:
		push_error("GameManager: cena final não encontrada em '%s'." % CENA_FINAL_CAMINHO)
		await TransicaoTela.revelar()
		return

	var erro: Error = arvore.change_scene_to_packed(cena_final)
	if erro != OK:
		push_error("GameManager: falha ao carregar a cena final (erro %d)." % erro)
		await TransicaoTela.revelar()
		return

	# Um frame de garantia (nova cena montada) e depois revela, sem depender deste nó.
	arvore.process_frame.connect(Callable(TransicaoTela, "revelar"), CONNECT_ONE_SHOT)
# --- FIM DA ALTERAÇÃO ---


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
	_circulo_entrada_pendente = null
	get_tree().reload_current_scene()
