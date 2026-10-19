extends CharacterBody2D
## Chefe Necromante.
## - Fica DORMENTE (parado, só flutuando) até o jogador entrar na AreaDeteccao.
## - Depois de acordar persegue o jogador (modo SEGUIR) ou foge dele (modo FUGIR).
## - Para invocar, primeiro vai a um ponto seguro (de preferência fora da câmera e longe do
##   jogador), sem atravessar paredes, e só então conjura (animação Attack).
## - Só é vulnerável enquanto conjura / espera o intervalo entre invocações.
## NÃO instancia inimigos: pede à fase pelo sinal `invocacao_solicitada` (UM inimigo por pedido)
## e acompanha os que a fase registra em `registrar_inimigo_invocado()`.
##
## A posição global do corpo é controlada SOMENTE pela física (velocity + move_and_slide).
## Nada aqui teleporta o chefe. A flutuação é visual (posição local do AnimatedSprite2D).
##
## A sequência de invocação é uma máquina de estados dirigida pelo _physics_process
## (sem `await` na lógica de ondas): interromper (dano/morte) é só trocar o estado.

## Emitido uma única vez, ao morrer, com a posição global exata da morte.
signal chefe_derrotado(posicao_global: Vector2)

## Pedido de invocação: a fase instancia `quantidade` inimigos (hoje sempre 1) e os registra de volta.
signal invocacao_solicitada(quantidade: int)

## Emitido cada vez que um inimigo invocado morre (ou sai da árvore) ENQUANTO o chefe está vivo,
## com a posição global onde ele estava. NÃO é emitido para os inimigos eliminados pela morte do chefe.
signal inimigo_invocado_morto(posicao_global: Vector2)

enum Estado {
	DORMENTE,       ## Parado, aguardando o jogador entrar na área de detecção.
	MOVENDO,        ## Perseguindo (SEGUIR) ou mantendo distância (FUGIR).
	FUGINDO_DANO,   ## Fuga rápida depois de levar dano.
	INDO_INVOCAR,   ## Indo até um ponto seguro para invocar.
	CONJURANDO,     ## Animação Attack até o momento do pedido de invocação.
	INTERVALO,      ## Esperando entre invocações (janela para o jogador atacar).
	MORRENDO,
}
## Como ele se move quando não está invocando.
enum ModoMovimento { FUGIR, SEGUIR }

const CANDIDATOS_FUGA: int = 10
const CANDIDATOS_INVOCACAO: int = 24
const PENALIDADE_TRAJETO_PERIGOSO: float = 100000.0
const BONUS_FORA_DA_TELA: float = 100000.0
## Pedidos seguidos sem nenhum inimigo registrado antes de abortar a onda.
const MAX_FALHAS_SEGUIDAS: int = 3
## Quantos destinos de invocação ele tenta antes de conjurar de onde estiver.
const MAX_TENTATIVAS_DESTINO: int = 3
const TEMPO_MIN_REAVALIAR: float = 0.15
## Preso = menos de DISTANCIA_PROGRESSO_MIN px de avanço durante TEMPO_PRESO segundos.
const TEMPO_PRESO: float = 0.6
const DISTANCIA_PROGRESSO_MIN: float = 8.0
## Depois de ficar preso seguindo o jogador, usa destinos alternativos por este tempo.
const DURACAO_DESVIO: float = 1.2
const INTERVALO_REVALIDAR_DESTINO: float = 0.5
const RETANGULO_ILIMITADO: Rect2 = Rect2(-10000000.0, -10000000.0, 20000000.0, 20000000.0)

const GRUPO_JOGADOR: StringName = &"player"
const SINAL_MORTE_INIMIGO: StringName = &"inimigo_morto"
const ANIM_IDLE: StringName = &"Idle"
const ANIM_ATAQUE: StringName = &"Attack"
const ANIM_DANO: StringName = &"Take_hit"
const ANIM_MORTE: StringName = &"Death"

@export_category("Vida")
@export var vida_maxima: int = 150
## Tempo do fade-out depois da animação de morte.
@export var death_fade_duracao: float = 1.0
## Se true, só leva dano enquanto invoca. Desligue para testar o dano em qualquer momento.
@export var vulneravel_somente_invocando: bool = true

@export_category("Movimento")
@export var velocidade: float = 120.0
## Quanto maior, mais rápido acelera e desacelera.
@export var suavidade: float = 3.0
@export var distancia_chegada: float = 12.0
@export var distancia_minima_deslocamento: float = 80.0
@export var distancia_maxima_deslocamento: float = 250.0

@export_category("Seguir o jogador")
## SEGUIR: paira perto do jogador e o acompanha. FUGIR: mantém distância.
## Depois de levar dano ele sempre foge por `duracao_fuga_apos_dano`, em qualquer modo.
@export var modo_movimento: ModoMovimento = ModoMovimento.SEGUIR
## Distância horizontal que ele tenta manter do jogador ao seguir.
@export var distancia_seguir: float = 220.0
## Quanto acima do jogador ele paira ao seguir.
@export var altura_seguir: float = 90.0

@export_category("Fuga e visão")
## Fora da invocação, destinos de perseguição/fuga ficam dentro da tela (só afeta a ESCOLHA do
## destino; a posição do corpo nunca é forçada).
@export var manter_na_tela_fora_da_invocacao: bool = true
## Distância das bordas da tela usada ao escolher destinos fora da invocação.
@export var margem_tela: float = 60.0
## Trajetos que passam mais perto que isso do jogador são evitados.
@export var distancia_segura_trajeto: float = 150.0
## De quanto em quanto tempo ele reavalia para onde fugir.
@export var intervalo_reavaliar_fuga: float = 0.5
@export var multiplicador_fuga_apos_dano: float = 1.8
@export var duracao_fuga_apos_dano: float = 2.0
## Marque se a arte do Necromante é desenhada virada para a direita.
@export var sprite_olha_para_direita: bool = true

@export_category("Colisão e arena")
## Camadas que contam como obstáculo ao PLANEJAR destinos. Deve conter as mesmas camadas de
## paredes/chão/plataformas que estão na Collision Mask do corpo do Necromante.
@export_flags_2d_physics var mascara_obstaculos: int = 1
## Limites extras (coordenadas GLOBAIS) usados só para escolher destinos. NÃO criam paredes.
## Deixe desligado se as paredes físicas da arena já bastam.
@export var usar_limites_manuais: bool = false
@export var limites_manuais: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)

@export_category("Detecção")
## Usados SÓ se o nó filho "AreaDeteccao" não existir (nesse caso uma área circular é criada).
@export var raio_deteccao_padrao: float = 400.0
@export_flags_2d_physics var mascara_deteccao_padrao: int = 2

@export_category("Flutuação")
@export var amplitude_flutuacao: float = 6.0
@export var velocidade_flutuacao: float = 2.0

@export_category("Invocação")
## Quantos inimigos cada onda tem (invocados um por vez).
@export_range(1, 50) var inimigos_por_onda: int = 10
## Tempo entre um inimigo invocado e o próximo (janela para o jogador atacar o chefe).
@export var intervalo_entre_invocacoes: float = 3.0
## Máximo de inimigos invocados vivos ao mesmo tempo. 0 = sem limite.
@export var maximo_inimigos_vivos: int = 4
## Espera antes da primeira onda, contada a partir do momento em que o chefe acorda.
@export var atraso_primeira_onda: float = 2.0
## Descanso depois que TODOS os inimigos de uma onda morrem, antes da próxima onda.
@export var atraso_entre_ondas: float = 3.0
## Em que ponto da animação Attack o inimigo é pedido (0 = início, 1 = fim).
@export_range(0.0, 1.0) var momento_da_invocacao: float = 0.5
## Tempo extra parado e vulnerável depois do ÚLTIMO inimigo da onda.
@export var tempo_extra_vulneravel: float = 1.5
## Depois de levar dano (e a fuga rápida acabar), espera isto antes de retomar a invocação.
@export var atraso_retomar_invocacao: float = 1.0

@export_category("Posicionamento para invocar")
## Distância do jogador considerada segura para conjurar.
@export var distancia_segura_invocacao: float = 350.0
## Até onde (a partir do chefe) ele procura pontos para se esconder.
@export var distancia_busca_invocacao: float = 900.0
## Quanto além da borda da tela um ponto precisa estar para contar como "fora da tela".
@export var margem_fora_da_tela: float = 40.0
## Multiplicador de velocidade ao ir para o ponto seguro.
@export var multiplicador_ida_invocar: float = 1.4
## Tempo máximo para chegar a um destino antes de desistir dele.
@export var tempo_maximo_ate_destino: float = 3.5

var _estado: Estado = Estado.DORMENTE
var _pausado: bool = false
var _destino: Vector2
var _tempo_reavaliacao: float = 0.0
var _tempo_fuga_rapida: float = 0.0
var _tempo_desvio: float = 0.0
var _fase_flutuacao: float = 0.0
var _sprite_y_base: float = 0.0
var _vida: int = 0
var _morto: bool = false
var _token_anim: int = 0
var _jogador: Node2D = null
var _inimigos_vivos: Array[Node] = []
var _tween_imune: Tween = null
var _area_deteccao: Area2D = null

# Detecção de travamento
var _pos_referencia: Vector2 = Vector2.ZERO
var _tempo_sem_progresso: float = 0.0

# Destino de invocação
var _tentativas_destino: int = 0
var _tempo_revalidar: float = 0.0
var _ponto_era_seguro: bool = false
var _ponto_era_fora_da_tela: bool = false

# Controle da onda
var _numero_onda: int = 0
var _onda_em_andamento: bool = false
var _restantes_na_onda: int = 0      # inimigos que ainda faltam ser invocados nesta onda
var _criados_na_onda: int = 0        # inimigos já invocados nesta onda
var _falhas_seguidas: int = 0
var _registros_na_chamada: int = 0   # quantos inimigos a fase registrou no último pedido
var _invocacao_bloqueada: bool = false
var _avisou_sem_fase: bool = false
var _tempo_para_invocar: float = 0.0 # contagem (fora da invocação) até a próxima sequência/onda
var _tempo_etapa: float = 0.0        # contagem da etapa atual (ida / conjuração / intervalo)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _colisao: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(&"enemies")
	# Modo flutuante: sem chão nem gravidade. A posição inicial do editor é preservada.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_vida = vida_maxima
	_destino = global_position
	_sprite_y_base = _sprite.position.y
	_fase_flutuacao = randf() * TAU
	_configurar_animacoes_sem_loop()
	_voltar_idle()
	_configurar_area_deteccao()
	_resetar_progresso()


func _physics_process(delta: float) -> void:
	if _morto:
		return

	_atualizar_flutuacao(delta)
	_virar_para_jogador()

	# Dormente (ou pausado pela fase): só flutua e olha para o jogador. Não se move nem invoca.
	if _estado == Estado.DORMENTE or _pausado:
		return

	match _estado:
		Estado.MOVENDO, Estado.FUGINDO_DANO:
			_processar_movimento(delta)
			_atualizar_ciclo_de_ondas(delta)
		Estado.INDO_INVOCAR:
			_processar_ida_ao_ponto(delta)
		Estado.CONJURANDO, Estado.INTERVALO:
			_processar_invocacao(delta)


# --- API pública ---

func get_vida() -> int:
	return _vida


func is_morto() -> bool:
	return _morto


func is_ativo() -> bool:
	return _estado != Estado.DORMENTE and not _pausado and not _morto


## Compatível com a versão anterior. `true` acorda o chefe (só tem efeito na primeira vez: o combate
## nunca é reiniciado). `false` depois de acordar apenas PAUSA o chefe, sem resetar nada.
func definir_ativo(ativo: bool) -> void:
	if _morto:
		return
	if ativo:
		_pausado = false
		_despertar()
	elif _estado != Estado.DORMENTE:
		_pausado = true
		velocity = Vector2.ZERO


## A fase chama isto para cada inimigo que instanciou a pedido do Necromante.
func registrar_inimigo_invocado(inimigo: Node) -> void:
	if inimigo == null or not is_instance_valid(inimigo):
		return
	if _morto:
		inimigo.queue_free() # chegou tarde demais: o chefe já morreu
		return
	if _inimigos_vivos.has(inimigo):
		return

	_inimigos_vivos.append(inimigo)
	_registros_na_chamada += 1
	# Rede de segurança: sai da contagem ao sair da árvore, por qualquer motivo.
	inimigo.tree_exiting.connect(_remover_da_onda.bind(inimigo), CONNECT_ONE_SHOT)
	# Contagem imediata na morte, se o inimigo tiver o sinal padrão do projeto.
	_conectar_sinal_morte(inimigo)


# --- Detecção do jogador ---

func _configurar_area_deteccao() -> void:
	_area_deteccao = get_node_or_null("AreaDeteccao") as Area2D
	if _area_deteccao == null:
		push_warning("Necromante: nó 'AreaDeteccao' não encontrado; criando uma área circular de raio %.0f." % raio_deteccao_padrao)
		_area_deteccao = Area2D.new()
		_area_deteccao.name = "AreaDeteccao"
		_area_deteccao.collision_layer = 0
		_area_deteccao.collision_mask = mascara_deteccao_padrao
		var forma: CollisionShape2D = CollisionShape2D.new()
		var circulo: CircleShape2D = CircleShape2D.new()
		circulo.radius = raio_deteccao_padrao
		forma.shape = circulo
		_area_deteccao.add_child(forma)
		add_child(_area_deteccao)

	# Conexões protegidas: nunca conecta duas vezes.
	if not _area_deteccao.body_entered.is_connected(_ao_corpo_entrar_na_deteccao):
		_area_deteccao.body_entered.connect(_ao_corpo_entrar_na_deteccao)
	if not _area_deteccao.area_entered.is_connected(_ao_area_entrar_na_deteccao):
		_area_deteccao.area_entered.connect(_ao_area_entrar_na_deteccao)


func _ao_corpo_entrar_na_deteccao(corpo: Node2D) -> void:
	if corpo.is_in_group(GRUPO_JOGADOR):
		_despertar()


## Cobre o caso do jogador ser detectado por uma Area2D filha dele (ex.: Hitbox_Area).
func _ao_area_entrar_na_deteccao(area: Area2D) -> void:
	var pai: Node = area.get_parent()
	if area.is_in_group(GRUPO_JOGADOR) or (pai != null and pai.is_in_group(GRUPO_JOGADOR)):
		_despertar()


## Acorda o chefe UMA única vez. Depois disso o estado nunca volta a DORMENTE,
## então entrar e sair da área não reinicia nada.
func _despertar() -> void:
	if _morto or _estado != Estado.DORMENTE:
		return
	if _area_deteccao != null:
		_area_deteccao.set_deferred("monitoring", false)
	_tempo_para_invocar = atraso_primeira_onda
	_tempo_reavaliacao = 0.0
	_destino = global_position
	_mudar_estado(Estado.MOVENDO)


# --- Dano e morte ---

## Chamado pelo AttackArea do Player (grupo "enemies"), igual aos demais inimigos.
func tomar_dano(quantidade: int, _posicao_jogador: Vector2 = Vector2.ZERO) -> void:
	if _morto:
		return

	# Dormente: o golpe o acorda, mas esse golpe não causa dano.
	if _estado == Estado.DORMENTE:
		_despertar()
		_piscar_imune()
		return
	if _pausado:
		_piscar_imune()
		return

	# Fora da invocação ele é imune (a menos que a invocação esteja bloqueada por erro,
	# caso em que fica vulnerável sempre para o jogo não travar).
	var vulneravel: bool = (
		_estado == Estado.CONJURANDO
		or _estado == Estado.INTERVALO
		or _invocacao_bloqueada
		or not vulneravel_somente_invocando
	)
	if not vulneravel:
		_piscar_imune()
		return

	_vida -= quantidade
	if _vida <= 0:
		_vida = 0
		_morrer()
		return

	_tocar_temporaria(ANIM_DANO)
	_reagir_ao_dano()


func _piscar_imune() -> void:
	if _tween_imune != null and _tween_imune.is_valid():
		_tween_imune.kill()
	_sprite.modulate = Color(0.6, 0.8, 1.0)
	_tween_imune = create_tween()
	_tween_imune.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Atingido: a sequência de invocação é interrompida (o que ainda faltava invocar continua
## pendente e é retomado depois) e ele foge mais rápido por um tempo.
func _reagir_ao_dano() -> void:
	var estava_invocando: bool = (
		_estado == Estado.INDO_INVOCAR
		or _estado == Estado.CONJURANDO
		or _estado == Estado.INTERVALO
	)
	_mudar_estado(Estado.FUGINDO_DANO)
	_tempo_fuga_rapida = duracao_fuga_apos_dano
	_tempo_reavaliacao = 0.0
	if estava_invocando:
		_tempo_para_invocar = duracao_fuga_apos_dano + atraso_retomar_invocacao


func _morrer() -> void:
	if _morto:
		return
	_morto = true # a partir daqui nenhuma etapa da invocação roda (ver _physics_process)
	_estado = Estado.MORRENDO

	# 1. Posição exata, registrada antes de qualquer remoção.
	var posicao_morte: Vector2 = global_position

	# 2-4. Para movimento, ataques e invocações.
	velocity = Vector2.ZERO
	_colisao.set_deferred("disabled", true)
	if _area_deteccao != null:
		_area_deteccao.set_deferred("monitoring", false)
	_token_anim += 1
	_restantes_na_onda = 0
	_onda_em_andamento = false
	if _tween_imune != null and _tween_imune.is_valid():
		_tween_imune.kill()

	# 5. Elimina só os inimigos invocados por ele que ainda estão vivos.
	_eliminar_inimigos_invocados()

	# 6. Avisa a fase (uma única vez, protegido por _morto).
	chefe_derrotado.emit(posicao_morte)

	# Animação de morte (existente), fade e remoção.
	_sprite.modulate = Color.WHITE
	if _tem_animacao(ANIM_MORTE):
		_sprite.play(ANIM_MORTE)
		await _esperar(_duracao_animacao(ANIM_MORTE))
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, death_fade_duracao)
	await tween.finished
	queue_free()


func _eliminar_inimigos_invocados() -> void:
	var copia: Array[Node] = _inimigos_vivos.duplicate()
	_inimigos_vivos.clear()
	for inimigo in copia:
		if is_instance_valid(inimigo):
			inimigo.queue_free()


# --- Ondas e invocação ---

## Roda enquanto o chefe se move (MOVENDO / FUGINDO_DANO): decide quando começar ou retomar a sequência.
func _atualizar_ciclo_de_ondas(delta: float) -> void:
	if _invocacao_bloqueada:
		return
	_purgar_inimigos_invalidos()
	if _tempo_para_invocar > 0.0:
		_tempo_para_invocar -= delta
		return

	if _restantes_na_onda > 0:
		# Onda em andamento (ou interrompida por dano/limite): retoma de onde parou,
		# se houver espaço. Continua somando o total da onda, sem duplicar.
		if not _limite_atingido():
			_iniciar_sequencia_de_invocacao()
	elif _inimigos_vivos.is_empty():
		# Nenhuma onda pendente e nenhum inimigo vivo: começa uma onda nova.
		_iniciar_nova_onda()
	# Senão: ainda há inimigos da onda atual vivos; espera todos morrerem.


func _iniciar_nova_onda() -> void:
	_numero_onda += 1
	_onda_em_andamento = true
	_restantes_na_onda = maxi(inimigos_por_onda, 1)
	_criados_na_onda = 0
	_falhas_seguidas = 0
	_iniciar_sequencia_de_invocacao()


## Toda sequência começa indo a um ponto seguro (o chefe normalmente está colado no jogador).
func _iniciar_sequencia_de_invocacao() -> void:
	_tentativas_destino = 0
	_ir_para_ponto_seguro()


func _ir_para_ponto_seguro() -> void:
	_escolher_destino_de_invocacao()
	_tempo_etapa = tempo_maximo_ate_destino
	_tempo_revalidar = INTERVALO_REVALIDAR_DESTINO
	_mudar_estado(Estado.INDO_INVOCAR)


## Chegou ao destino, travou ou estourou o tempo: tenta outro destino (poucas vezes) ou conjura
## de onde está. Nunca entra em ciclo infinito.
func _replanejar_ou_conjurar() -> void:
	_tentativas_destino += 1
	if _tentativas_destino >= MAX_TENTATIVAS_DESTINO:
		_comecar_conjuracao()
	else:
		_ir_para_ponto_seguro()


func _processar_ida_ao_ponto(delta: float) -> void:
	if global_position.distance_to(_destino) <= distancia_chegada:
		_comecar_conjuracao()
		return

	_tempo_etapa -= delta
	_tempo_revalidar -= delta
	var direcao: Vector2 = (_destino - global_position).normalized()
	_aplicar_velocidade(direcao * velocidade * multiplicador_ida_invocar, delta)

	if _tempo_etapa <= 0.0 or _sem_progresso(delta):
		_replanejar_ou_conjurar()
	elif _tempo_revalidar <= 0.0:
		# O jogador ou a câmera podem ter se movido: confere se o destino ainda serve.
		_tempo_revalidar = INTERVALO_REVALIDAR_DESTINO
		if not _ponto_ainda_valido(_destino):
			_replanejar_ou_conjurar()


## Toca Attack e agenda o pedido de UM inimigo para o momento configurado da animação.
func _comecar_conjuracao() -> void:
	_mudar_estado(Estado.CONJURANDO)
	_tempo_etapa = _duracao_animacao(ANIM_ATAQUE) * momento_da_invocacao
	_tocar_temporaria(ANIM_ATAQUE)


## Próxima invocação da mesma sequência: fica onde está, a menos que o ponto tenha deixado de servir.
func _iniciar_proxima_invocacao() -> void:
	if _ponto_ainda_valido(global_position):
		_comecar_conjuracao()
	else:
		_tentativas_destino = 0
		_ir_para_ponto_seguro()


func _processar_invocacao(delta: float) -> void:
	# Parado no ponto seguro: só desacelera (a física ainda o impede de atravessar paredes).
	_aplicar_velocidade(Vector2.ZERO, delta)

	_tempo_etapa -= delta
	if _tempo_etapa > 0.0:
		return

	match _estado:
		Estado.CONJURANDO:
			_executar_invocacao()
		Estado.INTERVALO:
			if _restantes_na_onda > 0 and not _invocacao_bloqueada and not _limite_atingido():
				_iniciar_proxima_invocacao()
			else:
				_encerrar_sequencia()


## Pede UM inimigo à fase e confere se ele foi realmente registrado.
func _executar_invocacao() -> void:
	if _morto:
		return
	_registros_na_chamada = 0
	if invocacao_solicitada.get_connections().is_empty():
		if not _avisou_sem_fase:
			_avisou_sem_fase = true
			push_warning("Necromante: nada está conectado a 'invocacao_solicitada' (script da fase anexado e com o Necromante encontrado?).")
	else:
		invocacao_solicitada.emit(1)

	if _morto:
		return

	if _registros_na_chamada > 0:
		_restantes_na_onda -= 1
		_criados_na_onda += 1
		_falhas_seguidas = 0
	else:
		_falhas_seguidas += 1
		push_warning("Necromante: a fase não registrou nenhum inimigo (falha %d/%d na onda %d)." % [
			_falhas_seguidas, MAX_FALHAS_SEGUIDAS, _numero_onda
		])
		if _falhas_seguidas >= MAX_FALHAS_SEGUIDAS:
			_abortar_onda()

	# Próxima etapa: espera o intervalo (janela para atacar) ou, se foi o último, o tempo extra.
	_mudar_estado(Estado.INTERVALO)
	if _restantes_na_onda > 0 and not _invocacao_bloqueada:
		_tempo_etapa = intervalo_entre_invocacoes
	else:
		_tempo_etapa = _duracao_animacao(ANIM_ATAQUE) * (1.0 - momento_da_invocacao) + tempo_extra_vulneravel

	_verificar_onda_concluida()


## Falhas repetidas ao criar inimigos: não insiste para sempre.
func _abortar_onda() -> void:
	push_error("Necromante: onda %d abortada após %d falhas seguidas (%d inimigos criados). Verifique 'cenas_inimigos' e o nó 'Enemys' no script da fase." % [
		_numero_onda, MAX_FALHAS_SEGUIDAS, _criados_na_onda
	])
	_restantes_na_onda = 0
	if _criados_na_onda == 0:
		_invocacao_bloqueada = true
		push_error("Necromante: nenhuma invocação funcionou; invocações desativadas e o chefe ficará vulnerável o tempo todo.")


## true se já há inimigos demais vivos para invocar mais um agora.
func _limite_atingido() -> bool:
	return maximo_inimigos_vivos > 0 and _inimigos_vivos.size() >= maximo_inimigos_vivos


## Termina a sequência normalmente e volta a se mover.
func _encerrar_sequencia() -> void:
	_mudar_estado(Estado.MOVENDO)
	_tempo_reavaliacao = 0.0


## A onda só termina quando nada falta invocar E não há inimigo vivo. Roda uma única vez por onda.
func _verificar_onda_concluida() -> void:
	if _morto or not _onda_em_andamento:
		return
	if _restantes_na_onda > 0 or not _inimigos_vivos.is_empty():
		return
	_onda_em_andamento = false
	_tempo_para_invocar = atraso_entre_ondas


## Rede de segurança: referências inválidas nunca devem impedir uma onda de terminar.
func _purgar_inimigos_invalidos() -> void:
	var removeu: bool = false
	for i in range(_inimigos_vivos.size() - 1, -1, -1):
		if not is_instance_valid(_inimigos_vivos[i]):
			_inimigos_vivos.remove_at(i)
			removeu = true
	if removeu:
		_verificar_onda_concluida()


func _conectar_sinal_morte(inimigo: Node) -> void:
	if not inimigo.has_signal(SINAL_MORTE_INIMIGO):
		return
	var quantidade_args: int = 0
	for info: Dictionary in inimigo.get_signal_list():
		if info["name"] == SINAL_MORTE_INIMIGO:
			quantidade_args = (info["args"] as Array).size()
			break
	var chamada: Callable = _remover_da_onda.bind(inimigo)
	if quantidade_args > 0:
		chamada = chamada.unbind(quantidade_args) # ignora os parâmetros do sinal (ex.: pontos)
	inimigo.connect(SINAL_MORTE_INIMIGO, chamada, CONNECT_ONE_SHOT)


## Idempotente: pode ser chamado pelo sinal de morte e depois pela saída da árvore.
func _remover_da_onda(inimigo: Node) -> void:
	if not _inimigos_vivos.has(inimigo):
		return
	_inimigos_vivos.erase(inimigo)

	if not _morto:
		var posicao: Vector2 = global_position
		if is_instance_valid(inimigo) and inimigo is Node2D:
			posicao = (inimigo as Node2D).global_position
		inimigo_invocado_morto.emit(posicao)

	_verificar_onda_concluida()


# --- Movimento: seguir / fugir ---

func _processar_movimento(delta: float) -> void:
	var fuga_rapida: bool = _estado == Estado.FUGINDO_DANO
	if fuga_rapida:
		_tempo_fuga_rapida -= delta
		if _tempo_fuga_rapida <= 0.0:
			_mudar_estado(Estado.MOVENDO)
			_tempo_reavaliacao = 0.0
			fuga_rapida = false
	_tempo_desvio = maxf(_tempo_desvio - delta, 0.0)

	# Seguindo: o destino acompanha o jogador a cada frame (exceto após dano ou ao desviar de parede).
	var seguindo: bool = (
		modo_movimento == ModoMovimento.SEGUIR
		and not fuga_rapida
		and _tempo_desvio <= 0.0
		and _obter_jogador() != null
	)

	if seguindo:
		_destino = _calcular_destino_seguir()
	else:
		_tempo_reavaliacao -= delta
		if _tempo_reavaliacao <= 0.0 or global_position.distance_to(_destino) <= distancia_chegada:
			_escolher_destino_de_fuga()
			_tempo_reavaliacao = intervalo_reavaliar_fuga

	var velocidade_maxima: float = velocidade
	if fuga_rapida:
		velocidade_maxima *= multiplicador_fuga_apos_dano

	var velocidade_alvo: Vector2
	if seguindo:
		# Desacelera ao chegar perto do ponto (sem ficar tremendo em cima dele).
		velocidade_alvo = ((_destino - global_position) * 2.0).limit_length(velocidade_maxima)
	else:
		velocidade_alvo = (_destino - global_position).normalized() * velocidade_maxima
	_aplicar_velocidade(velocidade_alvo, delta)

	# Bateu em algo: reavalia logo, mas com um intervalo mínimo (evita sortear destino todo frame).
	if get_slide_collision_count() > 0:
		_tempo_reavaliacao = minf(_tempo_reavaliacao, TEMPO_MIN_REAVALIAR)

	# Preso contra uma parede sem conseguir avançar: troca de destino por um tempo.
	var longe: bool = global_position.distance_to(_destino) > distancia_chegada * 3.0
	if not longe:
		_resetar_progresso()
	elif _sem_progresso(delta):
		_resetar_progresso()
		if seguindo:
			_tempo_desvio = DURACAO_DESVIO
		_escolher_destino_de_fuga()
		_tempo_reavaliacao = intervalo_reavaliar_fuga


## Ponto onde ele quer ficar ao seguir: ao lado do jogador, um pouco acima. Prefere o lado em que
## já está (não atravessa o jogador) e troca de lado se esse ponto ficar fora da área permitida.
func _calcular_destino_seguir() -> Vector2:
	var jogador: Node2D = _obter_jogador()
	var area: Rect2 = _area_permitida()
	var lado: float = 1.0 if global_position.x >= jogador.global_position.x else -1.0

	var melhor: Vector2 = global_position
	var menor_ajuste: float = INF
	for l: float in [lado, -lado]:
		var desejado: Vector2 = jogador.global_position + Vector2(l * distancia_seguir, -altura_seguir)
		var limitado: Vector2 = desejado.clamp(area.position, area.end)
		var ajuste: float = desejado.distance_to(limitado)
		if ajuste < menor_ajuste:
			menor_ajuste = ajuste
			melhor = limitado
	return melhor


## Entre candidatos aleatórios (já limitados pelas paredes), escolhe o mais longe do jogador,
## evitando passar perto dele.
func _escolher_destino_de_fuga() -> void:
	var area: Rect2 = _area_permitida()
	var jogador: Node2D = _obter_jogador()
	var distancia_min: float = minf(distancia_minima_deslocamento, distancia_maxima_deslocamento)

	var melhor: Vector2 = global_position
	var melhor_pontuacao: float = -INF

	for i in CANDIDATOS_FUGA:
		var direcao: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		var distancia: float = randf_range(distancia_min, distancia_maxima_deslocamento)
		var alvo: Vector2 = (global_position + direcao * distancia).clamp(area.position, area.end)
		var candidato: Vector2 = _ponto_alcancavel(global_position, alvo)

		var pontuacao: float = randf() # sem jogador: destino aleatório
		if jogador != null:
			var posicao_jogador: Vector2 = jogador.global_position
			pontuacao = candidato.distance_to(posicao_jogador)
			var ponto_mais_proximo: Vector2 = Geometry2D.get_closest_point_to_segment(posicao_jogador, global_position, candidato)
			if ponto_mais_proximo.distance_to(posicao_jogador) < distancia_segura_trajeto:
				pontuacao -= PENALIDADE_TRAJETO_PERIGOSO

		if pontuacao > melhor_pontuacao:
			melhor_pontuacao = pontuacao
			melhor = candidato

	_destino = melhor


# --- Movimento: ponto seguro para invocar ---

## Procura um ponto ALCANÇÁVEL (sem atravessar paredes): prefere fora da câmera e longe do jogador;
## se não houver, fica com o alcançável mais distante do jogador.
func _escolher_destino_de_invocacao() -> void:
	var jogador: Node2D = _obter_jogador()
	var limites: Rect2 = _limites_busca()
	var tela: Rect2 = _retangulo_visivel(-margem_fora_da_tela)

	var melhor: Vector2 = global_position
	var melhor_pontuacao: float = -INF

	for i in CANDIDATOS_INVOCACAO:
		# Direções espalhadas uniformemente (com sorteio dentro de cada fatia).
		var angulo: float = (float(i) + randf()) / float(CANDIDATOS_INVOCACAO) * TAU
		var distancia: float = randf_range(distancia_busca_invocacao * 0.4, distancia_busca_invocacao)
		var alvo: Vector2 = (global_position + Vector2.RIGHT.rotated(angulo) * distancia).clamp(limites.position, limites.end)
		var candidato: Vector2 = _ponto_alcancavel(global_position, alvo)

		var pontuacao: float = randf() # sem jogador: qualquer ponto alcançável
		if jogador != null:
			var posicao_jogador: Vector2 = jogador.global_position
			var distancia_jogador: float = candidato.distance_to(posicao_jogador)
			pontuacao = distancia_jogador
			if distancia_jogador >= distancia_segura_invocacao and not tela.has_point(candidato):
				pontuacao += BONUS_FORA_DA_TELA
			var ponto_mais_proximo: Vector2 = Geometry2D.get_closest_point_to_segment(posicao_jogador, global_position, candidato)
			if ponto_mais_proximo.distance_to(posicao_jogador) < distancia_segura_trajeto:
				pontuacao -= PENALIDADE_TRAJETO_PERIGOSO

		if pontuacao > melhor_pontuacao:
			melhor_pontuacao = pontuacao
			melhor = candidato

	_destino = melhor
	_ponto_era_seguro = false
	_ponto_era_fora_da_tela = false
	if jogador != null:
		_ponto_era_seguro = melhor.distance_to(jogador.global_position) >= distancia_segura_invocacao
		_ponto_era_fora_da_tela = _ponto_era_seguro and not tela.has_point(melhor)


## O ponto (destino ou posição atual) ainda serve? Usa histerese (0.6x) para não alternar à toa.
func _ponto_ainda_valido(ponto: Vector2) -> bool:
	var jogador: Node2D = _obter_jogador()
	if jogador == null:
		return true
	if _ponto_era_seguro and ponto.distance_to(jogador.global_position) < distancia_segura_invocacao * 0.6:
		return false
	if _ponto_era_fora_da_tela and _retangulo_visivel(-margem_fora_da_tela).has_point(ponto):
		return false
	return true


## Até onde o corpo consegue ir de `origem` em direção a `alvo` sem bater em obstáculos.
## Usa a forma real do CollisionShape2D (não só um raio fino), então respeita a largura do chefe.
func _ponto_alcancavel(origem: Vector2, alvo: Vector2) -> Vector2:
	var forma: Shape2D = _colisao.shape
	if forma == null:
		return alvo
	var transformacao: Transform2D = _colisao.global_transform
	transformacao.origin += origem - global_position

	var excluir: Array[RID] = [get_rid()]
	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = transformacao
	consulta.motion = alvo - origem
	consulta.collision_mask = mascara_obstaculos
	consulta.collide_with_areas = false
	consulta.exclude = excluir

	var resultado: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(consulta)
	if resultado.is_empty():
		return alvo
	return origem.lerp(alvo, resultado[0])


# --- Visão, orientação e área ---

## Retângulo do mundo que a câmera ativa mostra agora, reduzido pela margem
## (margem negativa = aumentado). Calculado do viewport: não presume onde a câmera está.
func _retangulo_visivel(margem: float) -> Rect2:
	var viewport: Viewport = get_viewport()
	var para_mundo: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var retangulo: Rect2 = para_mundo * viewport.get_visible_rect()
	return retangulo.grow(-margem)


## Limites usados para ESCOLHER destinos de invocação (as paredes físicas continuam mandando).
func _limites_busca() -> Rect2:
	if usar_limites_manuais and limites_manuais.has_area():
		return limites_manuais
	return RETANGULO_ILIMITADO


## Área para destinos de perseguição/fuga: limites manuais (se ativos) cruzados com a tela.
## Só escolhe destinos; nunca mexe na posição do corpo.
func _area_permitida() -> Rect2:
	var area: Rect2 = _limites_busca()
	if manter_na_tela_fora_da_invocacao:
		var visivel: Rect2 = _retangulo_visivel(margem_tela)
		if visivel.has_area():
			var corte: Rect2 = area.intersection(visivel)
			area = corte if corte.has_area() else (area if usar_limites_manuais else visivel)
	return area


func _virar_para_jogador() -> void:
	var jogador: Node2D = _obter_jogador()
	if jogador == null:
		return
	var jogador_a_direita: bool = jogador.global_position.x > global_position.x
	_sprite.flip_h = jogador_a_direita != sprite_olha_para_direita


func _obter_jogador() -> Node2D:
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group(GRUPO_JOGADOR) as Node2D
	return _jogador


## Flutuação só visual: mexe na posição LOCAL do sprite, nunca no corpo.
func _atualizar_flutuacao(delta: float) -> void:
	_fase_flutuacao += delta * velocidade_flutuacao
	_sprite.position.y = _sprite_y_base + sin(_fase_flutuacao) * amplitude_flutuacao


# --- Física e estado ---

func _aplicar_velocidade(alvo: Vector2, delta: float) -> void:
	velocity = velocity.lerp(alvo, 1.0 - exp(-suavidade * delta))
	move_and_slide()


func _mudar_estado(novo: Estado) -> void:
	_estado = novo
	_resetar_progresso()


func _resetar_progresso() -> void:
	_pos_referencia = global_position
	_tempo_sem_progresso = 0.0


## true se, querendo andar, o corpo avançou menos de DISTANCIA_PROGRESSO_MIN px em TEMPO_PRESO s.
func _sem_progresso(delta: float) -> bool:
	_tempo_sem_progresso += delta
	if global_position.distance_to(_pos_referencia) >= DISTANCIA_PROGRESSO_MIN:
		_resetar_progresso()
		return false
	return _tempo_sem_progresso >= TEMPO_PRESO


# --- Animações e utilidades ---

## Attack, Take_hit e Death não devem repetir sozinhas (mesmo padrão do Esqueleto).
func _configurar_animacoes_sem_loop() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		return
	for nome in [ANIM_ATAQUE, ANIM_DANO, ANIM_MORTE]:
		if frames.has_animation(nome):
			frames.set_animation_loop(nome, false)


func _tem_animacao(nome: StringName) -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(nome)


func _voltar_idle() -> void:
	if _tem_animacao(ANIM_IDLE):
		_sprite.play(ANIM_IDLE)


## Toca uma animação pontual e volta ao Idle depois. Só mexe na animação: não afeta a lógica
## de ondas. O token garante que uma animação mais nova cancele o "voltar ao Idle" da antiga.
func _tocar_temporaria(nome: StringName) -> void:
	if _morto or not _tem_animacao(nome):
		return
	_token_anim += 1
	var token: int = _token_anim
	_sprite.play(nome)
	await _esperar(_duracao_animacao(nome))
	if _morto or not is_inside_tree() or token != _token_anim:
		return
	_voltar_idle()


func _duracao_animacao(nome: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(nome):
		return 0.0
	var fps: float = frames.get_animation_speed(nome)
	if fps <= 0.0:
		return 0.0
	var total: float = 0.0
	for i in frames.get_frame_count(nome):
		total += frames.get_frame_duration(nome, i)
	return total / fps


## Espera usando um Timer filho: se o Necromante for removido, a espera some junto
## (sem erro de "função retomada depois de a instância ser removida").
func _esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	var temporizador: Timer = Timer.new()
	temporizador.one_shot = true
	temporizador.wait_time = maxf(segundos, 0.001)
	temporizador.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(temporizador)
	temporizador.start()
	await temporizador.timeout
	temporizador.queue_free()
