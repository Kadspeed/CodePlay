extends Control

## Script do Menu Principal do CodePlay.

# TODO: confirmar o caminho real da cena de jogo antes de usar.
const CENA_JOGO: String = "res://cenas/Mundo.tscn"

const COR_NORMAL: Color = Color(1, 1, 1, 1)
const COR_PRESSIONADO: Color = Color(0.6, 0.6, 0.6, 1)
const DURACAO_ANIMACAO_BOTAO: float = 0.08

const AMPLITUDE_FLUTUACAO_LOGO: float = 6.0
const VELOCIDADE_FLUTUACAO_LOGO: float = 1.5

@onready var botao_play: TextureButton = $Play
@onready var botao_sair: TextureButton = $Sair
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var logo: TextureRect = $Logo

var _logo_posicao_base: Vector2
var _tempo_flutuacao: float = 0.0


func _ready() -> void:
	_conectar_sinais()
	_tocar_musica_menu()
	_logo_posicao_base = logo.position


func _process(delta: float) -> void:
	_tempo_flutuacao += delta
	logo.position.y = _logo_posicao_base.y + sin(_tempo_flutuacao * VELOCIDADE_FLUTUACAO_LOGO) * AMPLITUDE_FLUTUACAO_LOGO


func _conectar_sinais() -> void:
	botao_play.pressed.connect(_on_botao_play_pressed)
	botao_sair.pressed.connect(_on_botao_sair_pressed)
	botao_play.button_down.connect(_on_botao_pressionado.bind(botao_play))
	botao_play.button_up.connect(_on_botao_solto.bind(botao_play))
	botao_sair.button_down.connect(_on_botao_pressionado.bind(botao_sair))
	botao_sair.button_up.connect(_on_botao_solto.bind(botao_sair))


func _on_botao_pressionado(botao: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(botao, "modulate", COR_PRESSIONADO, DURACAO_ANIMACAO_BOTAO)


func _on_botao_solto(botao: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(botao, "modulate", COR_NORMAL, DURACAO_ANIMACAO_BOTAO)


func _tocar_musica_menu() -> void:
	if audio_stream_player.stream != null and not audio_stream_player.playing:
		audio_stream_player.play()


func _on_botao_play_pressed() -> void:
	get_tree().change_scene_to_file(CENA_JOGO)


func _on_botao_sair_pressed() -> void:
	get_tree().quit()
