# scripts/transicao_tela.gd
extends CanvasLayer

## Camada de transição (fade in/out) reutilizável entre fases.
## Registrado como Autoload (Node Name: TransicaoTela) para poder ser
## chamado de qualquer lugar (ex.: GameManager) sem precisar instanciar
## manualmente.
##
## Cena correspondente (TransicaoTela.tscn):
## TransicaoTela (CanvasLayer)
## └── ColorRect (Anchors Preset = Full Rect, Color = preto, alpha inicial 0)

@onready var color_rect: ColorRect = $ColorRect

const DURACAO_PADRAO: float = 0.6

func _ready() -> void:
	layer = 100  # acima de tudo, inclusive da HUD
	# Começa transparente: assim o Menu Principal (ou qualquer cena que
	# carregue antes de um fade explícito) aparece normalmente. O
	# escurecimento só acontece quando alguma função chama escurecer()
	# explicitamente (ex.: GameManager ao trocar de fase).
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Escurece a tela gradualmente. Use antes de trocar de cena/fase.
func escurecer(duracao: float = DURACAO_PADRAO) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duracao)
	await tween.finished


## Revela a tela gradualmente. Use depois que a próxima cena/fase já
## estiver pronta e montada.
func revelar(duracao: float = DURACAO_PADRAO) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duracao)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
