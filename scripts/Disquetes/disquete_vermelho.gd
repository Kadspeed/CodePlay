extends Area2D
## disquete_vermelho.gd
##
## Script EXCLUSIVO do Disquete Vermelho. Usado somente pela cena
## Disquete_Vermelho.tscn — não é reaproveitado por outras cores.
##
## Responsabilidade única: representar o Disquete Vermelho no mundo, detectar
## o Player, mostrar o indicador de coleta e solicitar ao InventoryManager
## que adicione o item. Não conhece HUD, ItemDatabase, nem outros disquetes.
##
## ESTRUTURA DE NÓS ESPERADA (Disquete_Vermelho.tscn):
##   Disquete_Vermelho (Area2D)  <-- este script fica aqui, e É a área de detecção
##   ├── AnimatedSprite2D
##   ├── IndicadorInteracao (CollisionShape2D)  <-- forma de colisão da área
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

## ID fixo do item que este disquete representa. Sempre "disquete_vermelho",
## pois este script é exclusivo do Disquete Vermelho.
const NOME_ITEM: String = "disquete_vermelho"

## Nome exato da animação a ser tocada no AnimatedSprite2D.
const NOME_ANIMACAO: String = "Vermelho"

## Nome da ação de Input configurada no Input Map para coletar o item.
const ACAO_COLETAR: String = "coletar_item"

## Texto exibido no Label "Resposta" enquanto o Player está próximo.
const TEXTO_INDICADOR: String = "[E] Pegar"

## true enquanto o Player estiver dentro da área de interação.
var _player_por_perto: bool = false


# =============================================================================
# 2. REFERÊNCIAS DOS NÓS
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var indicador_interacao: Label = $Resposta


# =============================================================================
# 3. _ready()
# =============================================================================

func _ready() -> void:
	animated_sprite.play("Vermelho")
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

func _mostrar_indicador() -> void:
	indicador_interacao.text = TEXTO_INDICADOR
	indicador_interacao.visible = true


func _esconder_indicador() -> void:
	indicador_interacao.visible = false


# =============================================================================
# 6. COLETA DO ITEM
# =============================================================================

## Solicita ao InventoryManager que adicione o Disquete Vermelho ao inventário.
## Só remove o disquete do mundo se a adição for confirmada.
func _coletar_disquete() -> void:
	var sucesso: bool = InventoryManager.adicionar_item(NOME_ITEM)

	if sucesso:
		queue_free()
	else:
		push_warning("Inventário cheio, não foi possível pegar o Disquete Vermelho.")
