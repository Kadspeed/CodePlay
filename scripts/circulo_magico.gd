# scripts/circulo_magico.gd
# Anexar na RAIZ da cena circulo_magico.tscn (Circulo_Magico, Area2D).
extends Area2D

## Emitido UMA vez, quando o Player chega perto do círculo (já revelado).
## O GameManager escuta este sinal para avançar para a próxima fase.
signal jogador_alcancou

## Emitido quando o círculo termina de sumir (modo entrada).
signal desaparecimento_concluido

# --- Ajustável no Inspector ---

## Raio (px) da área de "chegar perto". Use 0 para manter o tamanho do
## CollisionShape2D definido na própria cena.
@export var raio_ativacao: float = 40.0

## Duração (s) do fade-in quando o círculo é revelado.
@export var duracao_fade_in: float = 0.6

@export_category("Modo Entrada")
## Se true, este círculo é de ENTRADA (início de fase): o GameManager o aciona
## ao carregar a fase, ele não detecta o Player e desaparece depois que o Player surge.
@export var modo_entrada: bool = false

## Tempo (s) entre o círculo terminar de aparecer e o Player surgir.
@export var atraso_player_surgir: float = 0.4

## Tempo (s) com o Player visível antes do círculo desativar.
@export var atraso_antes_de_desativar: float = 0.5

## Duração (s) do fade-out final.
@export var duracao_fade_out: float = 0.5

# --- Nomes das animações do AnimatedSprite2D ---
const ANIM_ATIVANDO: StringName = &"Ativando"
const ANIM_DESATIVANDO: StringName = &"Desativando"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D

var _revelado: bool = false
var _acionado: bool = false
var _entrada_em_andamento: bool = false


func _ready() -> void:
	add_to_group("circulo_magico")

	if sprite and sprite.sprite_frames:
		# As duas animações tocam uma vez só e param no último frame.
		for nome in [ANIM_ATIVANDO, ANIM_DESATIVANDO]:
			if sprite.sprite_frames.has_animation(nome):
				sprite.sprite_frames.set_animation_loop(nome, false)

	_aplicar_raio()
	body_entered.connect(_on_body_entered)
	_ocultar()


## Começa invisível e sem detectar nada (no editor continua visível para você posicionar).
func _ocultar() -> void:
	_revelado = false
	_acionado = false
	visible = false
	set_deferred("monitoring", false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ANIM_ATIVANDO):
		sprite.animation = ANIM_ATIVANDO
		sprite.frame = 0
		sprite.stop()


func _aplicar_raio() -> void:
	if raio_ativacao <= 0.0 or colisao == null:
		return
	var forma := colisao.shape as CircleShape2D
	if forma == null:
		return
	# Duplica para não alterar o recurso salvo na cena.
	var copia := forma.duplicate() as CircleShape2D
	copia.radius = raio_ativacao
	colisao.shape = copia


# ============================================================
# SAÍDA (Cidade Celestial): revelar -> Player chega perto -> Desativando
# ============================================================

## Chamada pelo GameManager quando o puzzle da Cidade Celestial é concluído.
## Mostra o círculo (fade-in + animação "Ativando") e só então liga a detecção.
func revelar() -> void:
	if modo_entrada:
		return
	if _revelado:
		return
	_revelado = true

	modulate.a = 0.0
	visible = true

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ANIM_ATIVANDO):
		sprite.play(ANIM_ATIVANDO)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, maxf(duracao_fade_in, 0.01))
	tween.tween_callback(_ativar_deteccao)


func _ativar_deteccao() -> void:
	# Se o Player já estiver dentro da área, body_entered dispara ao ligar o monitoring.
	set_deferred("monitoring", true)


func _on_body_entered(body: Node) -> void:
	if modo_entrada:
		return
	if not _revelado or _acionado:
		return
	if not body.is_in_group("player"):
		return

	_acionado = true
	set_deferred("monitoring", false)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ANIM_DESATIVANDO):
		sprite.play(ANIM_DESATIVANDO)

	jogador_alcancou.emit()


# ============================================================
# ENTRADA (Jardins Mecânicos): aparece -> Player surge -> Desativando -> some
# ============================================================

## Chamada pelo GameManager (só no modo entrada). Faz o círculo aparecer,
## chama `ao_surgir` (o Player aparece) e depois desativa e some com o círculo.
func executar_entrada(ao_surgir: Callable) -> void:
	if _entrada_em_andamento:
		return
	_entrada_em_andamento = true

	# Marcado como já acionado: o body_entered nunca emite jogador_alcancou aqui.
	_revelado = true
	_acionado = true
	set_deferred("monitoring", false)

	modulate.a = 0.0
	visible = true

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ANIM_ATIVANDO):
		sprite.play(ANIM_ATIVANDO)

	# 1) Círculo aparece (fade-in).
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, maxf(duracao_fade_in, 0.01))
	await fade_in.finished
	if not is_inside_tree():
		return

	# 2) Player surge em cima do círculo.
	if atraso_player_surgir > 0.0:
		await get_tree().create_timer(atraso_player_surgir).timeout
		if not is_inside_tree():
			return
	if ao_surgir.is_valid():
		ao_surgir.call()

	# 3) Pequena pausa e animação "Desativando".
	if atraso_antes_de_desativar > 0.0:
		await get_tree().create_timer(atraso_antes_de_desativar).timeout
		if not is_inside_tree():
			return

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ANIM_DESATIVANDO):
		sprite.play(ANIM_DESATIVANDO)
		await sprite.animation_finished
		if not is_inside_tree():
			return

	# 4) Fade-out e some.
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, maxf(duracao_fade_out, 0.01))
	await fade_out.finished

	visible = false
	_entrada_em_andamento = false
	desaparecimento_concluido.emit()
