extends CanvasLayer

## =============================================================
## HUD - Interface do jogador
##
## Responsabilidade única: janela do terminal. Conecta o
## Inventario à JanelaDisquete, repassando o Dictionary recebido
## via `disquete_selecionado`.
##
## A HUD NÃO controla a animação de vida (isso fica fora daqui)
## e NÃO conhece, armazena ou gerencia itens de inventário.
## =============================================================


#region 1. Referências dos nós

@onready var janela_disquete: Node = $JanelaDisquete
@onready var inventario: Node = $PainelInventario/Inventario

#endregion


#region 2. Inicialização

func _ready() -> void:
	_conectar_inventory_manager()


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


#region 3. Sistema da janela (terminal)

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


#region 4. Funções auxiliares

#endregion
