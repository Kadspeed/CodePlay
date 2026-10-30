extends Control
## Tela de introdução do CodePlay.
## Música + narração (dois AudioStreamPlayer), textos sincronizados,
## transições suaves e botão "Pular introdução".

# ---------------------------------------------------------------- Áudio
@export_group("Áudio")
## Música instrumental de fundo (toca em loop).
@export var musica: AudioStream
## OPÇÃO A: um arquivo de narração por parte (5 arquivos, na ordem).
## Se a parte tiver áudio, o texto fica na tela pela duração real do áudio.
@export var narracao_partes: Array[AudioStream] = []
## OPÇÃO B: uma única gravação com a narração inteira.
## Nesse caso, o tempo de cada texto vem de "duracoes".
@export var narracao_completa: AudioStream
@export_range(-60.0, 6.0, 0.5) var volume_musica_db: float = -8.0
@export_range(-60.0, 6.0, 0.5) var volume_narracao_db: float = 0.0

# ---------------------------------------------------------------- Textos e tempos
@export_group("Textos e tempos")
@export var textos: Array[String] = [
	"Há muito tempo, sete pergaminhos ancestrais guardavam os segredos da Codificação, responsáveis por manter o equilíbrio do mundo.",
	"Mas uma antiga ameaça está prestes a despertar. Uma força misteriosa pretende reiniciar toda a existência, apagando o mundo como o conhecemos.",
	"Agora, os sete Disquetes estão perdidos, espalhados por terras distantes.",
	"Ao seu lado, um homem-máquina será seu guia. Ele é o único capaz de decifrar os conhecimentos ancestrais, mas somente você poderá superar os desafios que protegem cada um deles.",
	"Sua jornada começa agora. Encontre os sete Disquetes e impeça que o mundo seja reiniciado."
]
## Segundos que cada texto permanece na tela (usado quando a parte NÃO tem
## áudio próprio em "narracao_partes"). Ajuste para sincronizar com sua voz.
@export var duracoes: Array[float] = [9.0, 11.0, 6.0, 13.0, 8.0]
@export_range(0.1, 5.0, 0.1) var fade_texto_entrada: float = 1.2
@export_range(0.1, 5.0, 0.1) var fade_texto_saida: float = 1.0
## Pausa (silêncio) entre um texto e o próximo.
@export_range(0.0, 5.0, 0.1) var pausa_entre_textos: float = 0.6
@export_range(0.0, 5.0, 0.1) var fade_inicial: float = 1.5
@export_range(0.0, 5.0, 0.1) var fade_final: float = 1.5

# ---------------------------------------------------------------- Visual
@export_group("Visual")
## Imagem opcional de fundo (ex.: arte do reino). Deixe vazio para usar só a cor.
@export var imagem_fundo: Texture2D
@export var cor_fundo: Color = Color(0.04, 0.05, 0.10)
@export var cor_texto: Color = Color(0.93, 0.86, 0.66)
@export var cor_sombra: Color = Color(0, 0, 0, 0.85)
@export var tamanho_fonte: int = 34
## Fonte opcional (use a mesma fonte do restante do CodePlay).
@export var fonte: Font

# ---------------------------------------------------------------- Destino
@export_group("Destino")
## Cena que contém o GameManager e o container "FaseAtual" (a cena principal do
## jogo, "Mundo"/"Cena_Principal"). O GameManager carrega a Fase 1 sozinho no
## _ready(), então a introdução só precisa abrir essa cena.
## AJUSTE para o caminho real no seu projeto.
@export_file("*.tscn") var cena_principal: String = "res://cenas/Mundo.tscn"

# ---------------------------------------------------------------- Nós
@onready var _fundo: ColorRect = $Fundo
@onready var _imagem: TextureRect = $ImagemFundo
@onready var _texto: Label = $AreaTexto/Texto
@onready var _botao_pular: Button = $BotaoPular
@onready var _cortina: ColorRect = $Cortina
@onready var _player_musica: AudioStreamPlayer = $Musica
@onready var _player_narracao: AudioStreamPlayer = $Narracao

var _encerrado: bool = false
var _tween_texto: Tween
var _tween_saida: Tween


func _ready() -> void:
	_aplicar_visual()
	_botao_pular.pressed.connect(pular)
	_botao_pular.grab_focus()
	_texto.modulate.a = 0.0
	_cortina.color = Color.BLACK
	_cortina.modulate.a = 1.0
	_executar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pular()


func _aplicar_visual() -> void:
	_fundo.color = cor_fundo
	_imagem.texture = imagem_fundo
	_imagem.visible = imagem_fundo != null
	_texto.add_theme_color_override("font_color", cor_texto)
	_texto.add_theme_color_override("font_shadow_color", cor_sombra)
	_texto.add_theme_constant_override("shadow_offset_x", 2)
	_texto.add_theme_constant_override("shadow_offset_y", 2)
	_texto.add_theme_font_size_override("font_size", tamanho_fonte)
	if fonte:
		_texto.add_theme_font_override("font", fonte)
	_botao_pular.add_theme_color_override("font_color", cor_texto)
	_botao_pular.add_theme_color_override("font_hover_color", Color.WHITE)


# ---------------------------------------------------------------- Sequência
func _executar() -> void:
	# Música (loop) e narração única, se houver.
	if musica:
		if "loop" in musica:
			musica.set("loop", true)
		_player_musica.stream = musica
		_player_musica.volume_db = -40.0
		_player_musica.play()
		create_tween().tween_property(_player_musica, "volume_db", volume_musica_db, fade_inicial)

	var fade_in := create_tween()
	fade_in.tween_property(_cortina, "modulate:a", 0.0, fade_inicial)
	await fade_in.finished
	if _encerrado:
		return

	_player_narracao.volume_db = volume_narracao_db
	if narracao_completa:
		_player_narracao.stream = narracao_completa
		_player_narracao.play()

	for i in textos.size():
		await _mostrar_parte(i)
		if _encerrado:
			return

	await _finalizar()


func _mostrar_parte(indice: int) -> void:
	_texto.text = textos[indice]

	var tempo: float
	var stream_parte: AudioStream = null
	if indice < narracao_partes.size():
		stream_parte = narracao_partes[indice]
	if stream_parte:
		_player_narracao.stream = stream_parte
		_player_narracao.play()
		tempo = stream_parte.get_length()
	elif indice < duracoes.size():
		tempo = duracoes[indice]
	else:
		tempo = 8.0

	# Entrada suave.
	_tween_texto = create_tween()
	_tween_texto.tween_property(_texto, "modulate:a", 1.0, fade_texto_entrada)
	await get_tree().create_timer(maxf(tempo - fade_texto_saida, 0.1)).timeout
	if _encerrado:
		return

	# Saída suave.
	_tween_texto = create_tween()
	_tween_texto.tween_property(_texto, "modulate:a", 0.0, fade_texto_saida)
	await _tween_texto.finished
	if _encerrado:
		return
	await get_tree().create_timer(pausa_entre_textos).timeout


# ---------------------------------------------------------------- Encerramento
func pular() -> void:
	_finalizar()


func _finalizar() -> void:
	if _encerrado:
		return
	_encerrado = true
	_botao_pular.disabled = true
	if _tween_texto:
		_tween_texto.kill()

	_tween_saida = create_tween().set_parallel(true)
	_tween_saida.tween_property(_cortina, "modulate:a", 1.0, fade_final)
	_tween_saida.tween_property(_texto, "modulate:a", 0.0, fade_final)
	_tween_saida.tween_property(_player_musica, "volume_db", -60.0, fade_final)
	_tween_saida.tween_property(_player_narracao, "volume_db", -60.0, fade_final)
	await _tween_saida.finished

	_player_narracao.stop()
	_player_musica.stop()
	_iniciar_primeira_fase()


func _iniciar_primeira_fase() -> void:
	if cena_principal.is_empty() or not ResourceLoader.exists(cena_principal):
		push_error("Introducao: cena principal inválida: '%s'. Ajuste 'Cena Principal' no Inspector." % cena_principal)
		return
	# O GameManager (dentro dessa cena) carrega a Fase 1 no _ready().
	get_tree().change_scene_to_file(cena_principal)
