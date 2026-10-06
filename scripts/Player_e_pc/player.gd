extends CharacterBody2D

# ============================================================
# 1. NÓS
# ============================================================

@onready var animated: AnimatedSprite2D = $CollisionShape2D/AnimatedSprite2D
@onready var interaction_area: Area2D = $"InteractionArea"
@onready var hitbox_area: Area2D = $HitboxArea
@onready var attack_area: Area2D = $AttackArea
@onready var camera: Camera2D = $Camera2D

# ============================================================
# 2. VARIÁVEIS DE ESTADO
# ============================================================

var nearby_pc = null
## Quando true, bloqueia toda a movimentação/pulo/ataque do Player (ver
## _physics_process e _unhandled_input). Usado tanto para o terminal do PC
## quanto para qualquer puzzle aberto — ver comentário detalhado na função
## respawn/_physics_process sobre como ativar e desativar essa flag.
var terminal_aberto: bool = false

# Sistema de vida
var vida_maxima: int = 100
var vida_atual: int = 100
var invencivel: bool = false
var tempo_invencivel: float = 1.0
var timer_invencivel: float = 0.0

# Sistema de ataque
var pode_atacar: bool = true
var dano_ataque: int = 15
var ataque_em_progresso: bool = false

# Knockback (apenas horizontal)
var knockback_ativo: bool = false
var tempo_knockback: float = 0.0
var knockback_forca: float = 150.0

# ============ PULO DUPLO ============
var pulos_restantes: int = 0
const PULOS_MAXIMOS: int = 1  # 🔥 2 pulos: 1 normal + 1 duplo
const JUMP_VELOCITY = -500.0

const SPEED = 200.0

# ============ ESTADO DE MORTE ============
var esta_morto: bool = false

# ============ SISTEMA DE RESPAWN ============
## Ponto para onde o Player retorna ao morrer ou cair. Antes era
## atualizado automaticamente a cada vez que o Player tocava o chão
## ("última posição segura"). Agora esse comportamento foi removido:
## quem define esse valor é o GameManager, através de
## definir_ponto_respawn(), sempre que uma fase é carregada ou trocada.
## Assim, tanto morte quanto queda levam o Player de volta ao
## SpawnPoint da fase atual — nunca a coordenadas fixas no código.
var ultima_posicao_segura: Vector2 = Vector2.ZERO
const MARGEM_RESPAWN: int = 80
var pode_respawnar: bool = true
const COOLDOWN_RESPAWN: float = 0.5
const DANO_QUEDA: int = 25  # 1 vida (100 HP / 4 vidas)

# 🔥 distância mínima de queda (a partir da última posição segura) para
# contar como "caiu no vazio". Isso evita que um pulo comum, que ultrapassa
# momentaneamente o limite da câmera por causa de um limit_bottom mal
# ajustado para a fase, seja confundido com uma queda real.
const QUEDA_MINIMA: float = 250.0

# ============================================================
# 3. SINAIS
# ============================================================

signal player_dano(quantidade: int, vida_restante: int)
signal player_morreu()
signal vida_atualizada(vida_atual: int, vida_maxima: int)

# ============================================================
# 4. INICIALIZAÇÃO
# ============================================================

func _ready():
	add_to_group("player")
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	
	if interaction_area:
		interaction_area.area_entered.connect(_on_interaction_area_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_area_exited)
	
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_entered)
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.monitoring = false
	
	# Configurar animação de ataque
	if animated.sprite_frames.has_animation("atack"):
		animated.sprite_frames.set_animation_loop("atack", false)
		print("✅ Animação 'atack' configurada")
	
	# 🔥 INICIALIZA PULOS
	pulos_restantes = PULOS_MAXIMOS
	
	# Valor inicial apenas como fallback (ex.: testar a cena da fase
	# sozinha, sem o GameManager). Em jogo normal, o GameManager chama
	# definir_ponto_respawn() logo após isso, sobrescrevendo o valor.
	ultima_posicao_segura = global_position
	
	# Validar câmera
	if not camera:
		push_warning("⚠️ Camera2D não encontrada! Sistema de respawn por limite desativado.")
	elif camera.limit_bottom <= 0:
		push_warning("⚠️ Camera2D.limit_bottom não configurado! Sistema de respawn por limite desativado.")
	
	print("✅ Player pronto!")

# ============================================================
# 5. PROCESSAMENTO FÍSICO
# ============================================================

func _physics_process(delta: float) -> void:
	# Invencibilidade
	if invencivel:
		timer_invencivel -= delta
		if timer_invencivel <= 0:
			invencivel = false
			modulate = Color.WHITE
	
	# Knockback temporário
	if knockback_ativo:
		tempo_knockback -= delta
		if tempo_knockback <= 0:
			knockback_ativo = false
	
	# SE ESTIVER MORTO, ZERA VELOCIDADE E NÃO FAZ NADA
	if esta_morto:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# SE O TERMINAL/PUZZLE ESTIVER ABERTO, TRAVA O PLAYER NO LUGAR.
	# 🔥 CORREÇÃO: a velocidade agora é zerada ANTES do move_and_slide()
	# e do "return". Antes, se o puzzle abrisse com o Player em movimento,
	# caindo ou sofrendo knockback, a velocity daquele frame continuava
	# sendo aplicada por move_and_slide() indefinidamente (porque nada
	# abaixo dessa checagem — gravidade, input, etc. — roda para zerá-la
	# de volta), fazendo o personagem continuar deslizando/flutuando
	# enquanto o puzzle estava aberto. Zerando aqui, o Player some com
	# qualquer velocidade residual e fica parado exatamente onde estava.
	# Isso não interfere em invencibilidade, knockback, morte ou vida:
	# esses sistemas usam suas próprias flags/timers, que continuam sendo
	# atualizados normalmente acima (ou ficam simplesmente pausados aqui,
	# já que nenhum dano/ataque/movimento pode ocorrer com o terminal
	# aberto de qualquer forma — ver tomar_dano(), que já ignora dano
	# enquanto terminal_aberto é true).
	if terminal_aberto:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# ============ MOVIMENTO ============
	
	# GRAVIDADE
	if not is_on_floor():
		velocity += get_gravity() * 2.1 * delta
	
	# MOVIMENTO HORIZONTAL
	var direction := Input.get_axis("left", "rigth")
	if direction and not knockback_ativo:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# ============ PULO DUPLO (APENAS 2 PULOS) ============
	if Input.is_action_just_pressed("up"):
		if is_on_floor():
			# 🔥 PRIMEIRO PULO (do chão)
			velocity.y = JUMP_VELOCITY
			pulos_restantes = PULOS_MAXIMOS - 1  # 🔥 Fica com 1 pulo restante
			print("💨 Pulo 1! Pulos restantes: ", pulos_restantes)
		elif pulos_restantes > 0:
			# 🔥 SEGUNDO PULO (pulo duplo)
			velocity.y = JUMP_VELOCITY
			pulos_restantes -= 1  # 🔥 Zera os pulos restantes
			print("💨 Pulo duplo! Pulos restantes: ", pulos_restantes)
	
	# 🔥 Resetar pulos quando tocar no chão (volta a ter 2 pulos)
	if is_on_floor():
		if pulos_restantes != PULOS_MAXIMOS:
			pulos_restantes = PULOS_MAXIMOS
			print("🔄 Pulos resetados! Pulos restantes: ", pulos_restantes)
	
	# ANIMAÇÕES
	_atualizar_animacao()
	
	# ============ INTERAÇÕES ============
	# Interação com PC
	if nearby_pc != null and Input.is_action_just_pressed("interact") and not terminal_aberto:
		print("Apertou E no PC!")
		if nearby_pc.has_method("open_terminal"):
			nearby_pc.open_terminal()
		return  # Sai para não fazer outras interações
	
	# Coletar disquete (qualquer tipo)
	if Input.is_action_just_pressed("interact") and not terminal_aberto:
		_coletar_disquete_proximo()
	
	move_and_slide()
	
	# ============ VERIFICAR QUEDA COM CAMERA2D ============
	# Só verifica se: não está morto, câmera existe, limite configurado, está caindo e ultrapassou o limite
	if not esta_morto and camera and camera.limit_bottom > 0:
		# Verifica se está caindo (velocity.y > 0) E ultrapassou o limite + margem
		if velocity.y > 0 and global_position.y > (camera.limit_bottom + MARGEM_RESPAWN):
			# 🔥 CORREÇÃO: só conta como "queda real" se o jogador também estiver
			# bem abaixo da última posição segura em que ele pisou. Isso evita
			# que um pulo comum (que sobe e desce sobre a mesma plataforma) seja
			# confundido com uma queda no vazio, caso o limit_bottom da câmera
			# esteja configurado perto demais do chão da fase.
			if global_position.y > (ultima_posicao_segura.y + QUEDA_MINIMA):
				respawn()

# ============================================================
# 5.1 INPUT NÃO-TRATADO (ATAQUE)
# ============================================================

## 🔥 CORREÇÃO: o ataque foi movido de _physics_process() (onde era lido via
## Input.is_action_just_pressed("atack1")) para cá.
##
## Motivo: "atack1" está vinculado ao clique do mouse. Input.is_action_just_pressed()
## lê o estado bruto do Input singleton e retornava true mesmo quando o clique já
## tinha sido consumido por um Button/Control de UI (Puzzle, Inventário,
## JanelaDisquete, HUD) — por isso clicar em qualquer botão de interface também
## disparava o ataque do Player.
##
## _unhandled_input() só recebe eventos que NENHUMA Control da árvore já tratou.
## Um Button, ao ser clicado, marca o evento como tratado automaticamente — então
## esse clique nunca chega até aqui, e o ataque não é acionado. Isso funciona mesmo
## como camada extra de proteção, independente de terminal_aberto estar
## corretamente sincronizado por cada sistema de UI.
func _unhandled_input(event: InputEvent) -> void:
	if terminal_aberto or esta_morto:
		return
	if event.is_action_pressed("atack1"):
		_realizar_ataque()
		get_viewport().set_input_as_handled()

# ============================================================
# 6. COLETA DE DISQUETES
# ============================================================

func _coletar_disquete_proximo():
	"""
	Procura o disquete mais próximo (qualquer cor) e solicita a coleta.
	O disquete se encarrega de enviar para o inventário e GameManager.
	"""
	# Buscar todos os disquetes (grupo comum)
	var disquetes = get_tree().get_nodes_in_group("disquete")
	var disquete_mais_proximo = null
	var menor_distancia = 80.0  # Distância máxima para coleta
	
	for disquete in disquetes:
		if not is_instance_valid(disquete):
			continue
		
		# Verificar se o disquete tem o método coletar
		if not disquete.has_method("coletar"):
			continue
		
		var distancia = global_position.distance_to(disquete.global_position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			disquete_mais_proximo = disquete
	
	if disquete_mais_proximo:
		# O disquete se encarrega de enviar para o inventário e GameManager
		disquete_mais_proximo.coletar()
		print("💾 Player solicitou coleta do disquete: ", disquete_mais_proximo.name)

# ============================================================
# 7. ANIMAÇÕES
# ============================================================

func _atualizar_animacao():
	# SE ESTIVER MORTO, MANTÉM IDLE
	if esta_morto:
		if animated.animation != "idle":
			animated.play("idle")
		return
	
	# ATUALIZAR DIREÇÃO DO SPRITE BASEADO NA VELOCIDADE HORIZONTAL
	if velocity.x != 0:
		animated.flip_h = velocity.x < 0
	
	# Se está atacando, mantém animação de ataque
	if ataque_em_progresso and animated.sprite_frames.has_animation("atack"):
		if animated.animation != "atack":
			animated.play("atack")
		return
	
	# Animações normais
	if not is_on_floor():
		if velocity.y < 0:
			animated.play("jump")
		else:
			animated.play("fall")
		return
	
	if velocity.x != 0:
		animated.play("run")
	else:
		animated.play("idle")

# ============================================================
# 8. ATAQUE
# ============================================================

func _realizar_ataque():
	if ataque_em_progresso or esta_morto:
		return
	
	print("⚔️ ATAQUE!")
	ataque_em_progresso = true
	
	# ATUALIZAR DIREÇÃO DO ATAQUE ANTES DE EXECUTAR
	var direcao = 1 if not animated.flip_h else -1
	
	# Ativar área de ataque
	if attack_area:
		attack_area.monitoring = true
		attack_area.position = Vector2(35 * direcao, -5)
	
	# Tocar animação de ataque
	if animated.sprite_frames.has_animation("atack"):
		animated.play("atack")
	else:
		modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE
	
	# Aguardar tempo do ataque
	await get_tree().create_timer(0.2).timeout
	
	# Desativar área de ataque
	if attack_area:
		attack_area.monitoring = false
	
	await get_tree().create_timer(0.2).timeout
	
	# Fim do ataque
	ataque_em_progresso = false

# 🔥 DETECTA Area2D (Monster_Sky)
func _on_attack_area_entered(area):
	if not ataque_em_progresso or esta_morto:
		return
	
	if area.is_in_group("enemies"):
		var enemy = area
		if enemy.has_method("tomar_dano"):
			enemy.tomar_dano(dano_ataque)
			print("⚔️ Dano causado em Area2D: ", dano_ataque)

# 🔥 DETECTA CharacterBody2D (Cogumelo)
func _on_attack_area_body_entered(body: Node2D):
	if not ataque_em_progresso or esta_morto:
		return
	
	if body.is_in_group("enemies"):
		var enemy = body
		if enemy.has_method("tomar_dano"):
			enemy.tomar_dano(dano_ataque)
			print("⚔️ Dano causado em CharacterBody2D: ", dano_ataque)

# ============================================================
# 9. SISTEMA DE DANO
# ============================================================

func tomar_dano(quantidade: int, posicao_inimigo: Vector2 = Vector2.ZERO):
	if invencivel or terminal_aberto or esta_morto:
		return false
	
	if vida_atual <= 0:
		return false
	
	vida_atual -= quantidade
	print("💥 Player tomou ", quantidade, " de dano! Vida: ", vida_atual, "/", vida_maxima)
	
	# EMITIR SINAL DE DANO PARA A HUD
	vida_atualizada.emit(vida_atual, vida_maxima)
	
	player_dano.emit(quantidade, vida_atual)
	
	if posicao_inimigo != Vector2.ZERO and not knockback_ativo:
		knockback_ativo = true
		tempo_knockback = 0.2
		var direcao = (global_position - posicao_inimigo).normalized()
		velocity.x = direcao.x * knockback_forca
	
	invencivel = true
	timer_invencivel = tempo_invencivel
	
	var tween = create_tween()
	tween.set_loops(6)
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5, 1), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if vida_atual <= 0:
		_morrer()
	
	return true

# ============================================================
# 10. MORTE
# ============================================================

func _morrer():
	print("💀 Player morreu!")
	esta_morto = true
	terminal_aberto = true
	ataque_em_progresso = false
	
	# ZERAR VELOCIDADE
	velocity = Vector2.ZERO
	
	# EMITIR SINAL DE MORTE
	player_morreu.emit()
	vida_atualizada.emit(0, vida_maxima)
	
	# DESATIVAR COLISÕES
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	
	# DESATIVAR ÁREAS DE INTERAÇÃO
	if interaction_area:
		interaction_area.set_deferred("monitoring", false)
	if hitbox_area:
		hitbox_area.set_deferred("monitoring", false)
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	
	# FORÇAR ANIMAÇÃO IDLE
	animated.play("idle")
	
	# APLICAR FADE OUT
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.5), 0.5)
	
	# DELAY ANTES DE RENASCER
	await get_tree().create_timer(1.5).timeout
	
	# 🔥 ALTERADO: antes disso chamava get_tree().reload_current_scene(),
	# recarregando a Cena_Principal inteira — o que resetaria também o
	# GameManager (fase atual, progresso, fases concluídas etc.), algo
	# incompatível com o sistema de fases. Agora o Player renasce no
	# SpawnPoint da fase atual, sem destruir o estado do GameManager.
	_respawnar_apos_morte()


func _respawnar_apos_morte() -> void:
	"""
	Reposiciona o Player no SpawnPoint da fase atual (guardado em
	'ultima_posicao_segura', mantido atualizado pelo GameManager via
	definir_ponto_respawn) e reativa tudo que _morrer() desativou.
	"""
	global_position = ultima_posicao_segura
	velocity = Vector2.ZERO
	
	# resetar_vida() já zera 'esta_morto' e reemite vida_atualizada.
	resetar_vida()
	
	terminal_aberto = false
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	
	if interaction_area:
		interaction_area.set_deferred("monitoring", true)
	if hitbox_area:
		hitbox_area.set_deferred("monitoring", true)
	
	modulate = Color.WHITE
	
	print("🔄 Player renasceu no SpawnPoint da fase atual: ", ultima_posicao_segura)

# ============================================================
# 11. INTERAÇÃO COM PC
# ============================================================

func _on_interaction_area_area_entered(area):
	if esta_morto:
		return
	
	print("Area entrou: ", area.name)
	
	if area.is_in_group("interactive_pc") or area.is_in_group("pc"):
		print("PC detectado!")
		nearby_pc = area
		# 🔥 CORRIGIDO: usar 'mostrar_prompt' em vez de 'show_prompt'
		if area.has_method("mostrar_prompt"):
			area.mostrar_prompt(true)

func _on_interaction_area_area_exited(area):
	if area == nearby_pc:
		if nearby_pc and nearby_pc.has_method("mostrar_prompt"):
			nearby_pc.mostrar_prompt(false)
		nearby_pc = null

func _on_hitbox_area_entered(area):
	if esta_morto:
		return
	if area.is_in_group("detection_area") or area.name == "DetectionArea":
		return
	
	if area.is_in_group("enemies"):
		var enemy = area
		if enemy.has_method("get_dano") and not invencivel:
			tomar_dano(enemy.get_dano(), enemy.global_position)

# ============================================================
# 12. CONTROLE DO TERMINAL / PUZZLE
# ============================================================

## Chame esta função (ou apenas atribua "terminal_aberto = true"
## diretamente) quando QUALQUER puzzle for aberto. É a mesma flag já usada
## pelo terminal do PC, então o Player já sabe travar movimento/pulo/
## ataque enquanto ela estiver true — ver _physics_process() e
## _unhandled_input().
func abrir_puzzle() -> void:
	terminal_aberto = true

func fechar_terminal():
	print("🔓 Player liberado do terminal")
	terminal_aberto = false

func desbloquear():
	terminal_aberto = false
	print("🔓 Player desbloqueado!")

# ============================================================
# 13. FUNÇÕES AUXILIARES
# ============================================================

func get_direcao():
	return -1 if animated.flip_h else 1

func get_vida_atual() -> int:
	return vida_atual

func get_vida_maxima() -> int:
	return vida_maxima

func get_percentual_vida() -> float:
	return float(vida_atual) / float(vida_maxima)

func curar(quantidade: int):
	if esta_morto:
		return
	vida_atual = min(vida_maxima, vida_atual + quantidade)
	print("❤️ Player curou ", quantidade, "! Vida: ", vida_atual, "/", vida_maxima)
	vida_atualizada.emit(vida_atual, vida_maxima)

func resetar_vida():
	vida_atual = vida_maxima
	invencivel = false
	esta_morto = false
	vida_atualizada.emit(vida_atual, vida_maxima)

# ============================================================
# 14. SISTEMA DE RESPAWN
# ============================================================

func respawn():
	"""
	Retorna o jogador para o SpawnPoint da fase atual (guardado em
	ultima_posicao_segura). Chamada automaticamente quando o jogador
	ultrapassa o limite inferior da câmera E caiu uma distância mínima
	(QUEDA_MINIMA) além do SpawnPoint, confirmando que se trata de uma
	queda real no vazio e não de um pulo comum. Aplica dano de 1 vida
	(25 HP) como penalidade pela queda.
	"""
	# Prevenir múltiplos respawns consecutivos
	if esta_morto or not pode_respawnar:
		return
	
	# Bloquear novos respawns durante o cooldown
	pode_respawnar = false
	
	# ============ APLICAR PENALIDADE DE VIDA ============
	# Aplica 25 de dano (1 vida) usando o sistema de dano existente
	# Isso garante que HUD, invencibilidade, efeitos visuais e morte funcionem corretamente
	tomar_dano(DANO_QUEDA)
	
	# ============ VERIFICAR SE MORREU ============
	# Se o jogador morreu com a queda, não respawna aqui — _morrer()
	# já cuida do renascimento no SpawnPoint.
	if esta_morto:
		# Liberar respawn após cooldown mesmo em caso de morte
		await get_tree().create_timer(COOLDOWN_RESPAWN).timeout
		pode_respawnar = true
		return
	
	# ============ EXECUTAR RESPAWN ============
	# Mover para o SpawnPoint da fase atual
	global_position = ultima_posicao_segura
	
	# Zerar completamente a velocidade
	velocity = Vector2.ZERO
	
	# Forçar atualização da física para este frame
	move_and_slide()
	
	print("🔄 Respawn: jogador perdeu 1 vida (25 HP) e retornou ao SpawnPoint em ", ultima_posicao_segura)
	print("❤️ Vida atual: ", vida_atual, "/", vida_maxima)
	
	# Liberar respawn após cooldown
	await get_tree().create_timer(COOLDOWN_RESPAWN).timeout
	pode_respawnar = true

# ============================================================
# 16. INTEGRAÇÃO COM O GAMEMANAGER
# ============================================================

func definir_ponto_respawn(posicao: Vector2) -> void:
	"""
	Chamada pelo GameManager sempre que uma fase é carregada (início do
	jogo ou troca de fase). Define para onde o sistema de respawn
	existente ('ultima_posicao_segura') deve trazer o Player quando ele
	morrer ou cair, e já posiciona o Player nesse ponto imediatamente
	(spawn da fase). Não substitui a lógica de respawn/morte — apenas
	atualiza o alvo que ela já usa.
	"""
	ultima_posicao_segura = posicao
	global_position = posicao
	velocity = Vector2.ZERO


func definir_limites_camera(esquerdo: int, superior: int, direito: int, inferior: int) -> void:
	"""
	Chamada pelo GameManager sempre que uma fase é carregada, para
	atualizar os limites da Camera2D do Player de acordo com a fase
	atual. Sem isso a câmera (e a detecção de queda em respawn(), que
	depende de camera.limit_bottom) continuaria usando os limites da
	fase anterior — causando exatamente o bug de cair e tomar dano sem
	parar assim que a fase troca.
	"""
	if camera == null:
		return
	camera.limit_left = esquerdo
	camera.limit_top = superior
	camera.limit_right = direito
	camera.limit_bottom = inferior

# ============================================================
# 15. FUNÇÕES DE DEBUG - REMOVIDAS COMPLETAMENTE
# ============================================================

# 🔥 FUNÇÃO REMOVIDA: _unhandled_input() antigo não existia — o ataque agora
# é tratado pela nova _unhandled_input() na seção 5.1, especificamente para
# resolver o bug de cliques em UI disparando ataque.
# Nenhum atalho de teclado deve permitir curar ou danificar o player.
# O player só deve ser afetado por interações normais do jogo.
