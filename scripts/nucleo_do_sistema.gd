extends Node
## Script da fase Nucleo_do_Sistema.
## Responsabilidades: instanciar os inimigos que o Necromante pede (em "Enemys"),
## registrá-los de volta nele e liberar o disquete onde o chefe morrer.
## O Necromante controla voo, vida, ondas e a eliminação dos inimigos invocados.
## Cada pedido do Necromante é de UM inimigo; o ritmo (um a cada X segundos) é dele.
##
## Local de nascimento: o inimigo é instanciado FORA da árvore, a forma de colisão REAL dele é lida
## e testada contra o cenário nos dois lados da âncora (jogador ou Necromante). Só nasce onde o corpo
## inteiro cabe, existe caminho livre até a âncora e (opcionalmente) há chão. Se nenhum ponto servir,
## o inimigo NÃO é criado (o Necromante conta isso como uma falha de invocação).

## Emitido uma vez, quando a batalha termina (útil para efeitos, música, HUD etc.).
signal batalha_concluida(posicao_global: Vector2)

## De onde parte a procura pelo ponto de nascimento.
enum OrigemSpawn {
	JOGADOR,     ## Perto do jogador (comportamento anterior).
	NECROMANTE,  ## Perto do Necromante, no lado que estiver livre.
}

const GRUPO_JOGADOR: StringName = &"player"
## Quantos pontos são testados em CADA lado, em cada altura (limite total = 3 alturas x 2 lados x isto).
const CANDIDATOS_POR_LADO: int = 6


## Corpo de teste do inimigo (forma real + posição relativa à origem dele).
class CorpoTeste:
	var forma: Shape2D = null
	## Transformação da forma relativa à origem do inimigo (inclui escala da raiz).
	var transformacao: Transform2D = Transform2D.IDENTITY
	## Retângulo que envolve a forma, relativo à origem do inimigo.
	var retangulo: Rect2 = Rect2()
	## Collision Mask do próprio inimigo (só usada se nenhuma máscara de cenário estiver definida).
	var mascara_proprio: int = 0


@export_category("Referências (se vazias, são procuradas pelo nome na fase)")
@export var necromante: Node
## Marcador Node2D "Disquete_Branco" (só marca a posição, não é o item coletável).
@export var marcador_disquete: Node2D
## Nó que recebe os inimigos invocados (o "Enemys" da fase).
@export var no_dos_inimigos: Node2D

@export_category("Ativação do chefe")
## Area2D na entrada da sala do chefe. Se definida, o Necromante fica parado e inofensivo
## até o Player entrar nela. Se vazia, procura uma Area2D chamada "AreaDeteccao" criada diretamente
## nesta cena da fase (as de inimigos, Vida etc. são ignoradas). Sem nenhuma, a luta começa sozinha.
@export var gatilho_sala: Area2D

@export_category("Invocação")
## Arraste aqui as cenas de res://cenas/Enemy/ que podem ser invocadas (sem o Necromante).
@export var cenas_inimigos: Array[PackedScene] = []
## Ponto de partida da procura (JOGADOR mantém o comportamento anterior).
@export var origem_spawn: OrigemSpawn = OrigemSpawn.JOGADOR
## Distância horizontal da âncora (esquerda ou direita) onde os inimigos nascem.
@export var distancia_spawn_minima: float = 120.0
@export var distancia_spawn_maxima: float = 260.0
## Quanto acima da âncora os inimigos nascem (eles caem até o chão). Se não couber, a procura
## tenta alturas maiores antes de desistir.
@export var altura_spawn_extra: float = 20.0

@export_category("Segurança do spawn (evita nascer dentro de estruturas)")
## Camadas de colisão do cenário (chão/paredes/estruturas). Se 0, usa a "mascara_obstaculos" do
## Necromante; se ela também for 0, usa a Collision Mask do próprio inimigo; se tudo for 0,
## nada é verificado (o inimigo pode nascer dentro de paredes!).
@export_flags_2d_physics var mascara_obstaculos: int = 0
## Usados SÓ se o inimigo não tiver um CollisionShape2D filho direto de um corpo físico.
## Tamanho aproximado do corpo do MAIOR inimigo invocado. Prefira exagerar um pouco.
@export var tamanho_corpo_inimigo: Vector2 = Vector2(48.0, 48.0)
## Deslocamento do centro do corpo em relação à origem do inimigo (ex.: origem nos pés = (0, -24)).
@export var centro_do_corpo: Vector2 = Vector2.ZERO
## Folga extra (px) ao redor do corpo do inimigo no teste de encaixe.
@export var margem_seguranca_corpo: float = 2.0
## Se true, não pode haver parede/estrutura entre a âncora e o ponto de nascimento
## (evita nascer do outro lado de uma parede). Testado em três alturas do corpo.
@export var exigir_linha_livre: bool = true
## Se true (e houver máscara de cenário), só nasce onde há chão logo abaixo.
@export var exigir_chao: bool = true
@export var altura_busca_chao: float = 300.0
## Retângulo global onde os inimigos podem nascer. Tamanho zero = sem limite.
@export var limites_spawn: Rect2 = Rect2()

@export_category("Vidas (cura durante a batalha)")
## Cena Vida (res://...): cai ao aparecer e cura o Player ao encostar.
@export var cena_vida: PackedScene
## A cada quantos inimigos mortos uma Vida aparece.
@export var mortes_por_vida: int = 2
## A Vida nasce esta distância acima de onde o inimigo morreu (e então cai).
@export var altura_spawn_vida: float = 40.0

@export_category("Recompensa")
## Cena REAL do disquete branco (a mesma usada pelo sistema de disquetes do jogo).
@export var cena_disquete_branco: PackedScene

var _batalha_concluida: bool = false
## Lado (1 = direita, -1 = esquerda) do próximo inimigo; alterna a cada spawn.
var _proximo_lado: int = 1
var _mortes_desde_ultima_vida: int = 0
var _chefe_ativado: bool = false
var _avisou_sem_cena_vida: bool = false
var _avisou_sem_mascara: bool = false
var _avisou_mascara_do_inimigo: bool = false


func _ready() -> void:
	_proximo_lado = 1 if randf() < 0.5 else -1

	if necromante == null:
		necromante = find_child("Necromante", true, false)
	if marcador_disquete == null:
		marcador_disquete = find_child("disquete_branco", true, false) as Node2D
	if no_dos_inimigos == null:
		no_dos_inimigos = find_child("Enemys", true, false) as Node2D
	if no_dos_inimigos == null:
		no_dos_inimigos = find_child("Enemies", true, false) as Node2D

	if necromante == null:
		push_error("Nucleo_do_Sistema: nó 'Necromante' não encontrado.")
		return
	if not necromante.has_signal("chefe_derrotado") or not necromante.has_signal("invocacao_solicitada"):
		push_error("Nucleo_do_Sistema: o Necromante não tem os sinais esperados (script anexado?).")
		return
	if not necromante.has_method("registrar_inimigo_invocado"):
		push_error("Nucleo_do_Sistema: o Necromante não tem o método 'registrar_inimigo_invocado' (script atualizado?).")
		return

	if no_dos_inimigos == null:
		push_error("Nucleo_do_Sistema: nó 'Enemys' não encontrado; defina 'no_dos_inimigos'.")
	if _cenas_validas().is_empty():
		push_warning("Nucleo_do_Sistema: 'cenas_inimigos' está vazio; nenhum inimigo será invocado.")
	if marcador_disquete == null:
		push_warning("Nucleo_do_Sistema: marcador 'Disquete_Branco' não encontrado.")
	if _mascara_cenario() == 0:
		push_warning("Nucleo_do_Sistema: 'mascara_obstaculos' é 0 aqui e no Necromante; será usada a Collision Mask do próprio inimigo. Marque as camadas do cenário no Inspector para uma validação confiável.")

	necromante.connect(&"invocacao_solicitada", _on_invocacao_solicitada)
	necromante.connect(&"chefe_derrotado", _on_chefe_derrotado, CONNECT_ONE_SHOT)

	if gatilho_sala == null:
		gatilho_sala = _procurar_area_deteccao()
		if gatilho_sala != null:
			print("Nucleo_do_Sistema: gatilho da sala encontrado: ", gatilho_sala.get_path())

	if gatilho_sala != null and necromante.has_method("definir_ativo"):
		necromante.call("definir_ativo", false)
		gatilho_sala.body_entered.connect(_on_gatilho_sala_entrou)
	elif gatilho_sala != null:
		push_warning("Nucleo_do_Sistema: o Necromante não tem 'definir_ativo' (necromante.gd atualizado?); 'gatilho_sala' ignorado.")
	if necromante.has_signal(&"inimigo_invocado_morto"):
		necromante.connect(&"inimigo_invocado_morto", _on_inimigo_invocado_morto)
	else:
		push_warning("Nucleo_do_Sistema: o Necromante não tem o sinal 'inimigo_invocado_morto' (necromante.gd atualizado?); as Vidas não vão aparecer.")


# --- Ativação do chefe ---

## Procura a Area2D "AreaDeteccao" que foi criada NESTA cena (owner = dono da cena). As de cenas
## instanciadas (inimigos, Vida, Necromante) têm outro owner e por isso são ignoradas.
func _procurar_area_deteccao() -> Area2D:
	var dono_da_cena: Node = owner if owner != null else self
	for no in find_children("AreaDeteccao", "Area2D", true, false):
		if no.owner == dono_da_cena:
			return no as Area2D
	return null


func _on_gatilho_sala_entrou(corpo: Node2D) -> void:
	if _chefe_ativado or not corpo.is_in_group(GRUPO_JOGADOR):
		return
	if not is_instance_valid(necromante):
		return
	_chefe_ativado = true
	necromante.call("definir_ativo", true)


# --- Invocação ---

func _on_invocacao_solicitada(quantidade: int) -> void:
	if _batalha_concluida or quantidade <= 0:
		return
	if not is_instance_valid(necromante):
		return

	var cenas: Array[PackedScene] = _cenas_validas()
	if cenas.is_empty():
		push_error("Nucleo_do_Sistema: invocação pedida, mas 'cenas_inimigos' não tem nenhuma cena válida.")
		return
	if no_dos_inimigos == null or not is_instance_valid(no_dos_inimigos):
		push_error("Nucleo_do_Sistema: invocação pedida, mas 'no_dos_inimigos' (Enemys) não está definido.")
		return

	var jogador: Node2D = get_tree().get_first_node_in_group(GRUPO_JOGADOR) as Node2D
	if jogador == null:
		push_warning("Nucleo_do_Sistema: jogador não encontrado no grupo '%s'." % GRUPO_JOGADOR)
		return

	for i in quantidade:
		# Alterna o lado preferido a cada inimigo para espalhar a onda; o lado só é usado
		# se estiver realmente livre (senão a procura vai para o outro).
		var lado: int = _proximo_lado
		_proximo_lado = -_proximo_lado
		var cena: PackedScene = cenas.pick_random() as PackedScene
		var ancora: Vector2 = _obter_ancora(jogador)
		if not _criar_inimigo(cena, ancora, lado):
			push_warning("Nucleo_do_Sistema: falha ao criar inimigo '%s'." % cena.resource_path)


## Ponto de partida da procura (jogador ou Necromante, conforme `origem_spawn`).
func _obter_ancora(jogador: Node2D) -> Vector2:
	if origem_spawn == OrigemSpawn.NECROMANTE and necromante is Node2D:
		return (necromante as Node2D).global_position
	return jogador.global_position


## Instancia o inimigo (ainda fora da árvore), acha um ponto válido para o corpo REAL dele, coloca
## em "Enemys" e registra no Necromante. Retorna false se falhar (inclui "nenhum ponto livre").
func _criar_inimigo(cena: PackedScene, ancora: Vector2, lado_preferido: int) -> bool:
	var no: Node = cena.instantiate()
	if no == null:
		push_error("Nucleo_do_Sistema: não foi possível instanciar '%s'." % cena.resource_path)
		return false

	var inimigo: Node2D = no as Node2D
	if inimigo == null:
		push_error("Nucleo_do_Sistema: a cena '%s' não tem um Node2D na raiz; ignorada." % cena.resource_path)
		no.free() # ainda fora da árvore: free() direto, sem deixar nó órfão
		return false

	var corpo: CorpoTeste = _extrair_corpo(inimigo)
	var resultado: PackedVector2Array = _procurar_posicao_spawn(ancora, lado_preferido, corpo)
	if resultado.is_empty():
		push_warning("Nucleo_do_Sistema: nenhuma posição livre para '%s'; inimigo não criado." % cena.resource_path)
		inimigo.free() # nunca entrou na árvore
		return false

	# Posição definida ANTES de entrar na árvore, para o _ready do inimigo já ver o local certo.
	inimigo.position = no_dos_inimigos.to_local(resultado[0])
	no_dos_inimigos.add_child(inimigo)

	# Avisa o Necromante, que passa a acompanhar este inimigo.
	necromante.call("registrar_inimigo_invocado", inimigo)
	return true


func _cenas_validas() -> Array[PackedScene]:
	var resultado: Array[PackedScene] = []
	for cena in cenas_inimigos:
		if cena != null:
			resultado.append(cena)
	return resultado


# --- Validação física do local de nascimento ---

## Lê a colisão REAL do inimigo: o maior CollisionShape2D habilitado que seja filho de um corpo
## físico (as Area2D de hitbox/detecção são ignoradas). Sem nenhum, usa o retângulo exportado.
func _extrair_corpo(inimigo: Node2D) -> CorpoTeste:
	var corpo: CorpoTeste = CorpoTeste.new()
	var objeto: CollisionObject2D = inimigo as CollisionObject2D
	if objeto != null:
		corpo.mascara_proprio = objeto.collision_mask

	var escala_raiz: Transform2D = Transform2D(0.0, inimigo.scale, 0.0, Vector2.ZERO)
	var maior_area: float = -1.0
	for no in inimigo.find_children("*", "CollisionShape2D", true, false):
		var colisao: CollisionShape2D = no as CollisionShape2D
		if colisao == null or colisao.disabled or colisao.shape == null:
			continue
		if not (colisao.get_parent() is PhysicsBody2D):
			continue

		var transf_local: Transform2D = colisao.transform
		var pai: Node = colisao.get_parent()
		while pai != null and pai != inimigo:
			if pai is Node2D:
				transf_local = (pai as Node2D).transform * transf_local
			pai = pai.get_parent()
		transf_local = escala_raiz * transf_local

		var retangulo: Rect2 = transf_local * colisao.shape.get_rect()
		var area: float = retangulo.size.x * retangulo.size.y
		if area > maior_area:
			maior_area = area
			corpo.forma = colisao.shape
			corpo.transformacao = transf_local
			corpo.retangulo = retangulo

	if corpo.forma == null:
		var reserva: RectangleShape2D = RectangleShape2D.new()
		reserva.size = tamanho_corpo_inimigo
		corpo.forma = reserva
		corpo.transformacao = Transform2D(0.0, centro_do_corpo)
		corpo.retangulo = corpo.transformacao * reserva.get_rect()
	return corpo


## Máscara de cenário definida na fase ou no Necromante (0 se nenhuma das duas).
func _mascara_cenario() -> int:
	if mascara_obstaculos != 0:
		return mascara_obstaculos
	if is_instance_valid(necromante):
		var do_chefe: Variant = necromante.get(&"mascara_obstaculos")
		if do_chefe is int and int(do_chefe) != 0:
			return int(do_chefe)
	return 0


func _mascara_efetiva(corpo: CorpoTeste) -> int:
	var mascara: int = _mascara_cenario()
	if mascara != 0:
		return mascara
	if corpo.mascara_proprio != 0:
		if not _avisou_mascara_do_inimigo:
			_avisou_mascara_do_inimigo = true
			push_warning("Nucleo_do_Sistema: sem 'mascara_obstaculos' definida; usando a Collision Mask do inimigo (pode incluir jogador/outros inimigos). Defina as camadas do cenário.")
		return corpo.mascara_proprio
	return 0


## Procura um ponto válido, no máximo 3 alturas x 2 lados x CANDIDATOS_POR_LADO testes.
## Tenta primeiro o lado preferido; um lado só é escolhido se tiver pontos realmente livres,
## então parede de um lado empurra a invocação para o outro. Retorna vazio se nada servir.
func _procurar_posicao_spawn(ancora: Vector2, lado_preferido: int, corpo: CorpoTeste) -> PackedVector2Array:
	var minimo: float = minf(distancia_spawn_minima, distancia_spawn_maxima)
	var maximo: float = maxf(distancia_spawn_minima, distancia_spawn_maxima)
	var mascara: int = _mascara_efetiva(corpo)
	if mascara == 0 and not _avisou_sem_mascara:
		_avisou_sem_mascara = true
		push_error("Nucleo_do_Sistema: nenhuma máscara de colisão disponível; o local de nascimento NÃO está sendo verificado.")

	var altura_corpo: float = corpo.retangulo.size.y
	var alturas: Array[float] = [
		altura_spawn_extra,
		altura_spawn_extra + altura_corpo * 0.5,
		altura_spawn_extra + altura_corpo,
	]

	for altura: float in alturas:
		var lado: int = lado_preferido
		for tentativa_de_lado in 2:
			var validos: Array[Vector2] = []
			for k in CANDIDATOS_POR_LADO:
				# Distâncias espalhadas entre mínimo e máximo, com sorteio dentro de cada faixa.
				var fracao: float = (float(k) + randf()) / float(CANDIDATOS_POR_LADO)
				var distancia: float = lerpf(minimo, maximo, fracao)
				var candidato: Vector2 = ancora + Vector2(lado * distancia, -altura)
				if _posicao_valida(candidato, ancora, corpo, mascara):
					validos.append(candidato)
			if not validos.is_empty():
				var escolhido: Vector2 = validos.pick_random()
				return PackedVector2Array([escolhido])
			lado = -lado # este lado não tem espaço nesta altura: tenta o outro

	return PackedVector2Array()


func _posicao_valida(posicao: Vector2, origem_visao: Vector2, corpo: CorpoTeste, mascara: int) -> bool:
	if limites_spawn.has_area() and not limites_spawn.has_point(posicao):
		return false
	if mascara == 0:
		return true

	var espaco: PhysicsDirectSpaceState2D = get_viewport().world_2d.direct_space_state

	# 1. O corpo INTEIRO (forma real do inimigo) precisa caber sem encostar em nada.
	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = corpo.forma
	consulta.transform = Transform2D(0.0, posicao) * corpo.transformacao
	consulta.collision_mask = mascara
	consulta.collide_with_areas = false
	consulta.margin = margem_seguranca_corpo
	if not espaco.intersect_shape(consulta, 1).is_empty():
		return false

	var centro_corpo: Vector2 = posicao + corpo.retangulo.get_center()

	# 2. Sem parede entre a âncora e o ponto: raios horizontais no topo, meio e base do corpo
	# (um raio só deixaria passar frestas mais baixas que o inimigo).
	if exigir_linha_livre:
		var meia_altura: float = maxf(corpo.retangulo.size.y * 0.5 - 2.0, 0.0)
		for deslocamento: float in [-meia_altura, 0.0, meia_altura]:
			var y: float = centro_corpo.y + deslocamento
			var visao: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				Vector2(origem_visao.x, y), Vector2(centro_corpo.x, y), mascara
			)
			if not espaco.intersect_ray(visao).is_empty():
				return false

	# 3. Precisa haver chão logo abaixo (evita nascer sobre um buraco).
	if exigir_chao:
		var raio: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			centro_corpo,
			centro_corpo + Vector2(0.0, corpo.retangulo.size.y * 0.5 + altura_busca_chao),
			mascara
		)
		if espaco.intersect_ray(raio).is_empty():
			return false

	return true


# --- Vidas durante a batalha ---

## Chamado pelo Necromante a cada inimigo invocado que morre com o chefe ainda vivo.
func _on_inimigo_invocado_morto(posicao_global: Vector2) -> void:
	if _batalha_concluida:
		return
	_mortes_desde_ultima_vida += 1
	if _mortes_desde_ultima_vida < maxi(mortes_por_vida, 1):
		return
	_mortes_desde_ultima_vida = 0
	# Adiado: a morte vem de um golpe do Player, dentro de um callback de colisão
	# (adicionar um corpo físico à árvore nesse momento causa erro de física).
	_criar_vida.call_deferred(posicao_global)


func _criar_vida(posicao_morte: Vector2) -> void:
	if _batalha_concluida or not is_inside_tree():
		return
	if cena_vida == null:
		if not _avisou_sem_cena_vida:
			_avisou_sem_cena_vida = true
			push_warning("Nucleo_do_Sistema: 'cena_vida' não definida; nenhuma Vida será criada.")
		return

	var no: Node = cena_vida.instantiate()
	if no == null:
		push_error("Nucleo_do_Sistema: não foi possível instanciar a cena da Vida.")
		return
	var vida: Node2D = no as Node2D
	if vida == null:
		push_error("Nucleo_do_Sistema: a cena da Vida não tem um Node2D na raiz.")
		no.free()
		return

	_adicionar_na_fase(vida, posicao_morte + Vector2(0.0, -altura_spawn_vida))


## Adiciona um item à fase (mesmo pai do marcador Disquete_Branco, ou do "Enemys") na posição global dada.
func _adicionar_na_fase(item: Node2D, posicao_global: Vector2) -> void:
	var pai: Node = self
	if marcador_disquete != null and marcador_disquete.get_parent() != null:
		pai = marcador_disquete.get_parent()
	elif no_dos_inimigos != null and no_dos_inimigos.get_parent() != null:
		pai = no_dos_inimigos.get_parent()

	# Posição já correta antes do _ready do item (quando o pai é um Node2D)...
	if pai is Node2D:
		item.position = (pai as Node2D).to_local(posicao_global)
	pai.add_child(item)
	# ...e garantida em coordenadas globais depois de entrar na árvore.
	item.global_position = posicao_global


# --- Conclusão da batalha ---

func _on_chefe_derrotado(posicao_global: Vector2) -> void:
	# Garante que a conclusão e a recompensa rodem uma única vez.
	if _batalha_concluida:
		return
	_batalha_concluida = true

	if marcador_disquete != null:
		marcador_disquete.global_position = posicao_global

	# Adiado: o sinal pode vir no meio de uma verificação de colisão (golpe do Player).
	_liberar_recompensa.call_deferred(posicao_global)

	batalha_concluida.emit(posicao_global)


func _liberar_recompensa(posicao_global: Vector2) -> void:
	if cena_disquete_branco == null:
		push_error("Nucleo_do_Sistema: 'cena_disquete_branco' não definida; o disquete não foi criado.")
		return

	var no: Node = cena_disquete_branco.instantiate()
	if no == null:
		push_error("Nucleo_do_Sistema: não foi possível instanciar a cena do disquete.")
		return
	var disquete: Node2D = no as Node2D
	if disquete == null:
		push_error("Nucleo_do_Sistema: a cena do disquete não tem um Node2D na raiz.")
		no.free()
		return

	# Entra no mesmo pai do marcador Disquete_Branco (o lugar certo da fase).
	_adicionar_na_fase(disquete, posicao_global)
