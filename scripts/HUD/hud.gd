extends CanvasLayer

## =============================================================
## HUD - Interface do jogador
##
## Responsabilidade única: interface do jogador. Possui apenas
## DUAS responsabilidades:
##   1. Barra de vida — escuta `vida_atualizada` do Player e
##      atualiza o AnimatedSprite2D correspondente.
##   2. Janela do terminal — conecta o Inventario à JanelaDisquete,
##      repassando o Dictionary recebido via `disquete_selecionado`.
##
## A HUD NÃO conhece, armazena ou gerencia itens de inventário.
## =============================================================


#region 1. Referências dos nós

@onready var sprite_vida: AnimatedSprite2D = $Vida
@onready var janela_disquete: Node = $JanelaDisquete
@onready var inventario: Node = $PainelInventario/Inventario

#endregion


#region 2. Constantes

const TOTAL_NIVEIS_VIDA: int = 5

#endregion


#region 3. Inicialização

func _ready() -> void:
	call_deferred("_conectar_player")
	_conectar_inventory_manager()


func _conectar_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("HUD: nenhum nó encontrado no grupo 'player'.")
		return

	if not player.has_signal("vida_atualizada"):
		push_warning("HUD: o Player não possui o sinal 'vida_atualizada'.")
		return

	player.vida_atualizada.connect(_on_vida_atualizada)


## Conecta ao sinal `disquete_selecionado` do Inventario.
func _conectar_inventory_manager() -> void:
	if inventario == null:
		push_error("HUD: nó 'Inventario' não encontrado na cena.")
		return

	if not inventario.has_signal("disquete_selecionado"):
		push_error("HUD: o nó 'Inventario' não possui o sinal 'disquete_selecionado'. Verifique se o Inventario.gd está anexado corretamente.")
		return

	inventario.disquete_selecionado.connect(_abrir_disquete)
	print("[HUD] Conectado ao sinal 'disquete_selecionado' do Inventario")

#endregion


#region 4. Sistema de vida

func _on_vida_atualizada(vida_atual: int, vida_maxima: int) -> void:
	if vida_maxima <= 0:
		push_warning("HUD: vida_maxima inválida (<= 0).")
		return

	var proporcao: float = clampf(float(vida_atual) / float(vida_maxima), 0.0, 1.0)

	var ultimo_indice: int = TOTAL_NIVEIS_VIDA - 1
	var indice: int = clampi(roundi(proporcao * ultimo_indice), 0, ultimo_indice)

	_tocar_animacao_vida(indice)


func _tocar_animacao_vida(indice: int) -> void:
	var nome_animacao: String = "vida%d" % indice
	if sprite_vida.animation != nome_animacao:
		sprite_vida.play(nome_animacao)

#endregion


#region 5. Sistema da janela (terminal)

## Handler chamado quando o Inventario emite `disquete_selecionado`.
func _abrir_disquete(dados_item: Dictionary) -> void:
	var nome_item: String = dados_item.get("nome", "desconhecido")
	print("[HUD] Disquete recebido: ", nome_item)

	if dados_item.is_empty():
		push_warning("HUD: 'disquete_selecionado' emitido com Dictionary vazio.")
		print("[HUD] ERRO: dados_item veio vazio, abortando abertura da janela.")
		return

	if janela_disquete == null:
		push_error("HUD: nó 'JanelaDisquete' não encontrado na cena.")
		print("[HUD] ERRO: referência 'janela_disquete' é null.")
		return

	print("[HUD] Abrindo JanelaDisquete")
	janela_disquete.abrir(dados_item)

#endregion


#region 6. Funções auxiliares

#endregion
