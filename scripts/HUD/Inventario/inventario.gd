extends Control
## Inventario.gd
##
## Fica anexado ao nó Control "Inventario", DENTRO da cena do HUD.
## Responsabilidade única: representar visualmente o estado do inventário.
##
## Este script NÃO guarda nenhum dado de item — ele só consulta o
## InventoryManager (Autoload) e reflete o estado nos 7 TextureButton.
## Toda a regra de "slot vazio", "não duplicar slot" e "ordem de
## preenchimento" já vive no InventoryManager; aqui só desenhamos o
## resultado.
##
## ESTRUTURA DE NÓS ESPERADA:
##   Inventario (Control)  <-- este script fica aqui
##   ├── Slot1 (TextureButton)
##   ├── Slot2 (TextureButton)
##   ├── Slot3 (TextureButton)
##   ├── Slot4 (TextureButton)
##   ├── Slot5 (TextureButton)
##   ├── Slot6 (TextureButton)
##   └── Slot7 (TextureButton)
##
## DEPENDÊNCIA EXTERNA:
##   - InventoryManager (Autoload): fonte dos dados e dos sinais.
##   - ItemDatabase (Autoload): consultado aqui para montar os dados
##     completos do item selecionado (nome, título, texto, ícone).

## Emitido quando o jogador clica num slot ocupado, já com os dados
## completos do item (vindos do ItemDatabase). O HUD.gd conecta este
## sinal para abrir a JanelaDisquete com as informações.
signal disquete_selecionado(dados_item: Dictionary)


# ---------------------------------------------------------------------------
# NÓS FILHOS
# ---------------------------------------------------------------------------

## Os 7 slots, na ORDEM correspondente ao índice usado pelo InventoryManager
## (índice 0 = Slot1, índice 1 = Slot2, ..., índice 6 = Slot7).
@onready var _slots: Array[TextureButton] = [
	$Slot1, $Slot2, $Slot3, $Slot4, $Slot5, $Slot6, $Slot7,
]


# ---------------------------------------------------------------------------
# CICLO DE VIDA
# ---------------------------------------------------------------------------

func _ready() -> void:
	_configurar_visual_dos_slots()
	_conectar_sinais_inventory_manager()
	_conectar_botoes_dos_slots()

	# Sincroniza a UI com o estado atual do inventário assim que o HUD
	# é carregado (importante ao trocar de fase, já que o InventoryManager
	# persiste os itens, mas esta UI é recriada do zero a cada cena).
	InventoryManager.atualizar_todos_os_slots()


# ---------------------------------------------------------------------------
# CONFIGURAÇÃO VISUAL DOS SLOTS
# ---------------------------------------------------------------------------

## Garante que todo TextureButton exiba seu ícone dentro do tamanho do
## slot, centralizado e com proporção preservada — independente da
## resolução original do PNG de cada disquete.
func _configurar_visual_dos_slots() -> void:
	for slot in _slots:
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED


# ---------------------------------------------------------------------------
# CONEXÃO DE SINAIS
# ---------------------------------------------------------------------------

## Escuta o InventoryManager para saber quando um slot muda visualmente.
func _conectar_sinais_inventory_manager() -> void:
	InventoryManager.slot_atualizado.connect(_ao_slot_atualizar)
	InventoryManager.inventario_cheio.connect(_ao_inventario_ficar_cheio)


## Conecta o clique de cada TextureButton ao índice correspondente,
## delegando a identificação do item ao InventoryManager — este script
## não guarda qual item está em qual slot, apenas consulta.
func _conectar_botoes_dos_slots() -> void:
	for indice in range(_slots.size()):
		var botao: TextureButton = _slots[indice]
		botao.pressed.connect(_ao_slot_pressionado.bind(indice))


# ---------------------------------------------------------------------------
# REAÇÃO AOS SINAIS DO INVENTORYMANAGER
# ---------------------------------------------------------------------------

## Atualiza o ícone do TextureButton correspondente.
## icone == null significa slot vazio: limpa a textura.
func _ao_slot_atualizar(indice_slot: int, _nome_item: String, icone: Texture2D) -> void:
	if not _indice_e_valido(indice_slot):
		push_warning("Inventario: slot_atualizado com índice inválido '%d'." % indice_slot)
		return

	_slots[indice_slot].texture_normal = icone


## Feedback simples para o jogador quando não há espaço para um novo item.
func _ao_inventario_ficar_cheio() -> void:
	push_warning("Inventario: inventário está cheio.")


# ---------------------------------------------------------------------------
# REAÇÃO A CLIQUES DO JOGADOR
# ---------------------------------------------------------------------------

## Um TextureButton foi clicado: descobre qual item está nesse slot,
## busca os dados completos no ItemDatabase e emite disquete_selecionado
## para quem for abrir a janela (HUD.gd / JanelaDisquete.gd).
##
## Fluxo:
##   índice do slot
##       → InventoryManager.obter_item_por_slot(indice)
##       → nome_item ("" se o slot estiver vazio)
##       → ItemDatabase.get_item(nome_item)
##       → dados_item (Dictionary)
##       → disquete_selecionado.emit(dados_item)
func _ao_slot_pressionado(indice_slot: int) -> void:
	print("[INVENTARIO] Slot clicado: ", indice_slot)

	var nome_item: String = InventoryManager.obter_item_por_slot(indice_slot)

	if nome_item.is_empty():
		print("[INVENTARIO] Slot ", indice_slot, " está vazio. Nenhuma ação.")
		return  # Slot vazio: nada para mostrar.

	print("[INVENTARIO] Item encontrado: ", nome_item)

	var dados_item: Dictionary = ItemDatabase.get_item(nome_item)

	if dados_item.is_empty():
		push_warning("Inventario: nenhum dado encontrado no ItemDatabase para '%s'." % nome_item)
		print("[INVENTARIO] ERRO: ItemDatabase não retornou dados para '", nome_item, "'")
		return

	print("[INVENTARIO] Dados encontrados no ItemDatabase")
	print("[INVENTARIO] Emitindo disquete_selecionado")

	disquete_selecionado.emit(dados_item)


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

func _indice_e_valido(indice_slot: int) -> bool:
	return indice_slot >= 0 and indice_slot < _slots.size()
