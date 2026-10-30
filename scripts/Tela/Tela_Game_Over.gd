extends Control

## Tela de Game Over do CodePlay — Godot 4.7.
## Não procura nem mantém referências ao GameManager/Player da cena anterior.

const CENA_MUNDO: String = "uid://2ygfblgnx8u3"
const CENA_MENU_PRINCIPAL: String = "uid://c2mexibk6o745"
const COR_NORMAL: Color = Color(1, 1, 1, 1)
const COR_PRESSIONADO: Color = Color(0.6, 0.6, 0.6, 1)
const DURACAO_ANIMACAO_BOTAO: float = 0.08

@onready var botao_tentar_novamente: TextureButton = $"Tentar novamente"
@onready var botao_desistir: TextureButton = $Desistir

var _acao_em_andamento := false


func _ready() -> void:
	botao_tentar_novamente.pressed.connect(_on_tentar_novamente_pressed)
	botao_desistir.pressed.connect(_on_desistir_pressed)

	botao_tentar_novamente.button_down.connect(
		_animar_botao.bind(botao_tentar_novamente, COR_PRESSIONADO)
	)
	botao_tentar_novamente.button_up.connect(
		_animar_botao.bind(botao_tentar_novamente, COR_NORMAL)
	)

	botao_desistir.button_down.connect(
		_animar_botao.bind(botao_desistir, COR_PRESSIONADO)
	)
	botao_desistir.button_up.connect(
		_animar_botao.bind(botao_desistir, COR_NORMAL)
	)


func _animar_botao(botao: TextureButton, cor: Color) -> void:
	var tween := create_tween()
	tween.tween_property(botao, "modulate", cor, DURACAO_ANIMACAO_BOTAO)


func _on_tentar_novamente_pressed() -> void:
	if _acao_em_andamento:
		return

	if EstadoJogo.fase_para_reiniciar <= 0:
		push_error("Game Over: fase da morte não foi registrada em EstadoJogo.")
		return

	_acao_em_andamento = true
	await _trocar_cena(CENA_MUNDO)


func _on_desistir_pressed() -> void:
	if _acao_em_andamento:
		return

	_acao_em_andamento = true
	EstadoJogo.preparar_retorno_menu()

	await _trocar_cena(CENA_MENU_PRINCIPAL)


func _trocar_cena(caminho: String) -> void:
	var arvore := get_tree()

	await TransicaoTela.escurecer()

	var erro := arvore.change_scene_to_file(caminho)

	if erro != OK:
		push_error(
			"Game Over: falha ao carregar '%s' (erro %d)." % [caminho, erro]
		)

		_acao_em_andamento = false
		TransicaoTela.revelar()
		return

	arvore.process_frame.connect(
		Callable(TransicaoTela, "revelar"),
		CONNECT_ONE_SHOT
	)
