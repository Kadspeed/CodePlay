extends Control

## Script do Menu Principal do CodePlay.

const CENA_JOGO: String = "res://cenas/Mundo.tscn"

const COR_NORMAL: Color = Color(1, 1, 1, 1)
const COR_PRESSIONADO: Color = Color(0.6, 0.6, 0.6, 1)
const DURACAO_ANIMACAO_BOTAO: float = 0.08

const AMPLITUDE_FLUTUACAO_LOGO: float = 6.0
const VELOCIDADE_FLUTUACAO_LOGO: float = 1.5

# O game_manager.gd está anexado à raiz de Mundo.tscn (Mundo, Node2D).
# Se um dia ele for movido para um nó filho, o Menu o procura por este nome.
const NOME_NO_GAME_MANAGER: String = "GameManager"
const PROPRIEDADE_MODO_DESENVOLVEDOR: String = "modo_desenvolvedor"

@onready var botao_play: TextureButton = $Play
@onready var botao_sair: TextureButton = $Sair
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var logo: TextureRect = $Logo

var _logo_posicao_base: Vector2
var _tempo_flutuacao: float = 0.0


func _ready() -> void:
	# Modo Desenvolvedor: pula o menu e entra direto em Mundo.tscn.
	# O GameManager é quem decide a fase inicial.
	if _deve_pular_menu():
		_entrar_direto_no_jogo()
		return

	_conectar_sinais()
	_tocar_musica_menu()
	_logo_posicao_base = logo.position


func _process(delta: float) -> void:
	_tempo_flutuacao += delta
	logo.position.y = _logo_posicao_base.y + sin(_tempo_flutuacao * VELOCIDADE_FLUTUACAO_LOGO) * AMPLITUDE_FLUTUACAO_LOGO


## Lê o valor salvo de `modo_desenvolvedor` no GameManager de Mundo.tscn,
## sem iniciar a cena. A cena é instanciada só na memória (nunca entra na árvore),
## então nenhum _ready() roda: sem Player, sem fase, sem fade, sem som.
func _deve_pular_menu() -> bool:
	var cena_jogo: PackedScene = load(CENA_JOGO) as PackedScene
	if cena_jogo == null:
		push_warning("Menu: não foi possível carregar '%s' para checar o modo desenvolvedor." % CENA_JOGO)
		return false

	var instancia: Node = cena_jogo.instantiate()
	var ativo: bool = _ler_modo_desenvolvedor(instancia)
	instancia.free()

	print("Menu: modo_desenvolvedor lido de Mundo.tscn = ", ativo)
	return ativo


func _ler_modo_desenvolvedor(raiz: Node) -> bool:
	var game_manager: Node = _encontrar_game_manager(raiz)
	if game_manager == null:
		push_warning("Menu: não encontrei o GameManager em '%s' (nem na raiz com a propriedade '%s', nem um nó chamado '%s')." % [CENA_JOGO, PROPRIEDADE_MODO_DESENVOLVEDOR, NOME_NO_GAME_MANAGER])
		return false

	return game_manager.get(PROPRIEDADE_MODO_DESENVOLVEDOR) == true


## Localiza o GameManager dentro da instância de Mundo.tscn.
## 1) A raiz, se ela tiver o script do GameManager (estrutura atual do projeto).
## 2) Senão, um nó filho chamado "GameManager".
func _encontrar_game_manager(raiz: Node) -> Node:
	if PROPRIEDADE_MODO_DESENVOLVEDOR in raiz:
		return raiz

	var filho: Node = raiz.find_child(NOME_NO_GAME_MANAGER, true, false)
	if filho != null and PROPRIEDADE_MODO_DESENVOLVEDOR in filho:
		return filho
	return null


func _entrar_direto_no_jogo() -> void:
	# Impede qualquer atividade do menu no frame em que a troca é agendada.
	visible = false
	set_process(false)
	get_tree().change_scene_to_file(CENA_JOGO)


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
