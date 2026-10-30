extends Area2D
## disquete_branco.gd
##
## Script EXCLUSIVO do Disquete Branco. Usado somente pela cena
## Disquete_Branco.tscn — não é reaproveitado por outras cores.
##
## Responsabilidade única: representar o Disquete Branco no mundo, detectar
## o Player, mostrar o indicador de coleta e solicitar ao InventoryManager
## que adicione o item. Não conhece HUD, ItemDatabase, nem outros disquetes.
##
## ESTRUTURA DE NÓS ESPERADA (Disquete_Branco.tscn):
##   Disquete_Branco (Area2D)    <-- este script fica aqui, e É a área de detecção
##   ├── AnimatedSprite2D
##   ├── CollisionShape2D                        <-- forma de colisão da área
##   └── Resposta (Label)                        <-- texto "[E] Pegar"
##
## IMPORTANTE: como o próprio nó raiz já é um Area2D, os sinais de
## detecção do Player (body_entered/body_exited) são conectados
## diretamente em "self" — não existe um segundo Area2D filho.
##
## DEPENDÊNCIA EXTERNA:
##   - InventoryManager (Autoload): precisa expor
##     adicionar_item(nome_item: String) -> bool
##   - Input Map: precisa existir a ação "coletar_item", mapeada para a
##     tecla E (Project Settings → Input Map). Trocada de Q para E pois
##     Q já é usada para interagir com o PC no jogo.
##   - Player: precisa estar no grupo "player".


# =============================================================================
# 1. VARIÁVEIS E CONSTANTES
# =============================================================================

## ID fixo do item que este disquete representa. Sempre "disquete_branco",
## pois este script é exclusivo do Disquete Branco.
const NOME_ITEM: String = "disquete_branco"

## Nome exato da animação a ser tocada no AnimatedSprite2D.
const NOME_ANIMACAO: String = "Branco"

## Nome da ação de Input configurada no Input Map para coletar o item.
const ACAO_COLETAR: String = "coletar_item"

## Texto exibido no Label "Resposta" enquanto o Player está próximo.
const TEXTO_INDICADOR: String = "[E] Pegar"

# --- Aparência do indicador (ajuste aqui, sem mexer na cena) ---

## Tamanho VISUAL final da fonte do indicador (em pixels do jogo).
const INDICADOR_TAMANHO_FONTE: int = 12

## Fator de nitidez: o texto é desenhado N vezes maior e reduzido via scale,
## evitando letras embaçadas quando o jogo é ampliado (zoom/stretch).
## Aumente (ex.: 6 ou 8) se ainda ficar borrado; use 1 para desativar.
const INDICADOR_SUPERAMOSTRAGEM: int = 4

## Cor do texto (dourado mágico).
const INDICADOR_COR_TEXTO: Color = Color("#F5C542")

## Cor do contorno (roxo bem escuro, para dar contraste em qualquer fundo).
const INDICADOR_COR_CONTORNO: Color = Color("#1B1033")

## Espessura VISUAL do contorno, em pixels do jogo. Se estiver pesado, use 2 ou 3.
const INDICADOR_TAMANHO_CONTORNO: int = 4

## Cor e deslocamento da sombra do texto.
const INDICADOR_COR_SOMBRA: Color = Color(0.0, 0.0, 0.0, 0.6)
const INDICADOR_DESLOCAMENTO_SOMBRA: int = 1

## Se true, centraliza o indicador horizontalmente na origem deste nó
## (assume que o disquete está centrado na origem da cena). Se o texto
## ficar deslocado para o lado, coloque false e posicione o Label no editor.
const INDICADOR_CENTRALIZAR: bool = true

# --- Animação do indicador ---

## Duração do fade-in ao aparecer, em segundos.
const INDICADOR_DURACAO_FADE: float = 0.15

## Amplitude (em pixels) e duração de meio ciclo da flutuação vertical.
const INDICADOR_AMPLITUDE_FLUTUACAO: float = 2.0
const INDICADOR_DURACAO_FLUTUACAO: float = 0.6

## true enquanto o Player estiver dentro da área de interação.
var _player_por_perto: bool = false

## Posição Y original do Label, usada como base da flutuação.
var _indicador_y_base: float = 0.0

## Tweens do indicador (guardados para poder cancelá-los ao esconder).
var _tween_fade: Tween = null
var _tween_flutuacao: Tween = null


# =============================================================================
# 2. REFERÊNCIAS DOS NÓS
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label_indicador: Label = $Resposta


# =============================================================================
# 3. _ready()
# =============================================================================

func _ready() -> void:
	animated_sprite.play(NOME_ANIMACAO)
	_estilizar_indicador()
	_esconder_indicador()
	_conectar_sinais_area()  # self já é o Area2D de detecção


func _unhandled_input(event: InputEvent) -> void:
	if not _player_por_perto:
		return

	if event.is_action_pressed(ACAO_COLETAR):
		_coletar_disquete()
		get_viewport().set_input_as_handled()


# =============================================================================
# 4. DETECÇÃO DO JOGADOR
# =============================================================================

## Conecta os sinais do próprio nó (self), já que o nó raiz é o Area2D
## responsável por detectar o Player.
func _conectar_sinais_area() -> void:
	body_entered.connect(_ao_corpo_entrar_na_area)
	body_exited.connect(_ao_corpo_sair_da_area)


func _ao_corpo_entrar_na_area(corpo: Node2D) -> void:
	if not corpo.is_in_group("player"):
		return

	_player_por_perto = true
	_mostrar_indicador()


func _ao_corpo_sair_da_area(corpo: Node2D) -> void:
	if not corpo.is_in_group("player"):
		return

	_player_por_perto = false
	_esconder_indicador()


# =============================================================================
# 5. CONTROLE DO INDICADOR
# =============================================================================

## Aplica o visual do indicador (fonte, cores, contorno, sombra, tamanho e
## alinhamento). Chamado uma vez no _ready().
##
## O texto é desenhado em tamanho maior (INDICADOR_SUPERAMOSTRAGEM) e o Label
## é reduzido com scale, o que mantém o tamanho visual e deixa as letras nítidas.
func _estilizar_indicador() -> void:
	var label: Label = label_indicador
	var s: int = maxi(INDICADOR_SUPERAMOSTRAGEM, 1)

	label.text = TEXTO_INDICADOR
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", INDICADOR_TAMANHO_FONTE * s)
	label.add_theme_color_override("font_color", INDICADOR_COR_TEXTO)
	label.add_theme_color_override("font_outline_color", INDICADOR_COR_CONTORNO)
	label.add_theme_constant_override("outline_size", INDICADOR_TAMANHO_CONTORNO * s)
	label.add_theme_color_override("font_shadow_color", INDICADOR_COR_SOMBRA)
	label.add_theme_constant_override("shadow_offset_x", INDICADOR_DESLOCAMENTO_SOMBRA * s)
	label.add_theme_constant_override("shadow_offset_y", INDICADOR_DESLOCAMENTO_SOMBRA * s)

	label.pivot_offset = Vector2.ZERO
	label.scale = Vector2.ONE / float(s)

	# Encolhe a caixa do Label até o tamanho mínimo do texto.
	label.size = Vector2.ZERO

	if INDICADOR_CENTRALIZAR:
		# get_minimum_size() já reflete o texto/fonte atuais; label.size só
		# seria atualizado no próximo frame. Arredonda para não cair em
		# posição fracionária (causa de letras borradas).
		label.position.x = roundf(-label.get_minimum_size().x * label.scale.x / 2.0)

	label.position.y = roundf(label.position.y)
	_indicador_y_base = label.position.y


func _mostrar_indicador() -> void:
	_cancelar_animacoes_indicador()

	label_indicador.text = TEXTO_INDICADOR
	label_indicador.position.y = _indicador_y_base
	label_indicador.modulate.a = 0.0
	label_indicador.visible = true

	# Fade-in rápido.
	_tween_fade = create_tween()
	_tween_fade.tween_property(label_indicador, "modulate:a", 1.0, INDICADOR_DURACAO_FADE)

	# Flutuação vertical suave e contínua, enquanto o indicador estiver visível.
	_tween_flutuacao = create_tween().set_loops()
	_tween_flutuacao.tween_property(
		label_indicador, "position:y",
		_indicador_y_base - INDICADOR_AMPLITUDE_FLUTUACAO,
		INDICADOR_DURACAO_FLUTUACAO
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_flutuacao.tween_property(
		label_indicador, "position:y",
		_indicador_y_base,
		INDICADOR_DURACAO_FLUTUACAO
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _esconder_indicador() -> void:
	_cancelar_animacoes_indicador()
	label_indicador.position.y = _indicador_y_base
	label_indicador.visible = false


## Cancela os tweens ativos do indicador, evitando animações duplicadas
## quando o Player entra e sai da área rapidamente.
func _cancelar_animacoes_indicador() -> void:
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()
	if _tween_flutuacao and _tween_flutuacao.is_valid():
		_tween_flutuacao.kill()


# =============================================================================
# 6. COLETA DO ITEM
# =============================================================================

## Solicita ao InventoryManager que adicione o Disquete Branco ao inventário.
## Só remove o disquete do mundo se a adição for confirmada.
func _coletar_disquete() -> void:
	var sucesso: bool = InventoryManager.adicionar_item(NOME_ITEM)

	if sucesso:
		queue_free()
	else:
		push_warning("Inventário cheio, não foi possível pegar o Disquete Branco.")
