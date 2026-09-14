extends Node
## InventoryManager.gd
##
## Autoload (Singleton) responsável exclusivamente por administrar QUAIS
## itens o jogador possui, em quais dos 7 slots eles estão, e por avisar
## o resto do jogo (via sinais) quando isso muda.
##
## Este script NÃO sabe nada sobre:
##   - conteúdo/descrição/ícone dos itens (isso é do ItemDatabase.gd)
##   - como desenhar a UI, abrir janelas, mostrar texto (isso é do HUD.gd)
##   - disquetes no mundo, tecla de coleta, Player (isso é do disquete.gd)
##
## DEPENDÊNCIA EXTERNA:
##   - ItemDatabase (Autoload) precisa expor:
##       get_item(nome_item: String) -> Dictionary
##       tem_item(nome_item: String) -> bool   (opcional; ver _item_e_valido)
##     Usado apenas para VALIDAR se um nome_item existe antes de guardá-lo,
##     e para obter o ícone ao emitir sinais de atualização de slot.
##
## CONFIGURAÇÃO OBRIGATÓRIA (ver explicação após o código):
##   Project Settings → Globals → Autoload
##   Path: res://.../InventoryManager.gd
##   Name: InventoryManager


# ---------------------------------------------------------------------------
# SINAIS
# ---------------------------------------------------------------------------

## Emitido quando um item é adicionado com sucesso a um slot.
signal item_adicionado(nome_item: String, indice_slot: int)

## Emitido quando um item é removido de um slot.
signal item_removido(nome_item: String, indice_slot: int)

## Emitido sempre que o estado do inventário muda (adição, remoção, limpeza).
## Sinal "genérico" para quem só precisa saber "algo mudou, redesenhe tudo".
signal inventario_atualizado

## Emitido quando uma tentativa de adicionar item falha por falta de espaço.
signal inventario_cheio

## Emitido quando um slot específico deve ter seu visual atualizado.
## O HUD conecta este sinal e aplica `icone` em seu TextureButton.
## icone vem como null quando o slot está vazio (HUD deve limpar o botão).
signal slot_atualizado(indice_slot: int, nome_item: String, icone: Texture2D)


# ---------------------------------------------------------------------------
# CONSTANTES
# ---------------------------------------------------------------------------

## Quantidade fixa de slots do inventário.
const TOTAL_SLOTS: int = 7


# ---------------------------------------------------------------------------
# ESTADO
# ---------------------------------------------------------------------------

## Array de tamanho fixo (TOTAL_SLOTS) com o ID do item em cada slot,
## ou null se o slot estiver vazio.
## Índice do array == índice do slot (0 -> Slot1, 1 -> Slot2, ...).
var _itens_por_slot: Array = []


# ---------------------------------------------------------------------------
# CICLO DE VIDA
# ---------------------------------------------------------------------------

func _ready() -> void:
	_inicializar_slots()


## Cria os 7 slots vazios. Separado em função própria para poder ser
## reaproveitado por limpar_inventario().
func _inicializar_slots() -> void:
	_itens_por_slot.clear()
	_itens_por_slot.resize(TOTAL_SLOTS)
	_itens_por_slot.fill(null)


# ---------------------------------------------------------------------------
# API PÚBLICA — ADICIONAR / REMOVER
# ---------------------------------------------------------------------------

## Tenta adicionar um item ao primeiro slot vazio disponível.
## Retorna true se adicionado com sucesso, false caso contrário
## (item inválido ou inventário cheio).
func adicionar_item(nome_item: String) -> bool:
	if not _item_e_valido(nome_item):
		push_warning("InventoryManager: tentativa de adicionar item inválido '%s'." % nome_item)
		return false

	var indice_slot: int = procurar_slot_vazio()

	if indice_slot == -1:
		inventario_cheio.emit()
		return false

	_itens_por_slot[indice_slot] = nome_item

	item_adicionado.emit(nome_item, indice_slot)
	atualizar_slot(indice_slot)
	inventario_atualizado.emit()

	return true


## Remove a PRIMEIRA ocorrência de nome_item do inventário, se existir.
## Retorna true se algo foi removido, false se o item não foi encontrado.
func remover_item(nome_item: String) -> bool:
	var indice_slot: int = _procurar_slot_com_item(nome_item)

	if indice_slot == -1:
		push_warning("InventoryManager: tentativa de remover item inexistente '%s'." % nome_item)
		return false

	_itens_por_slot[indice_slot] = null

	item_removido.emit(nome_item, indice_slot)
	atualizar_slot(indice_slot)
	inventario_atualizado.emit()

	return true


## Esvazia todos os slots do inventário (ex.: novo jogo, reset de progresso).
func limpar_inventario() -> void:
	_inicializar_slots()
	atualizar_todos_os_slots()
	inventario_atualizado.emit()


# ---------------------------------------------------------------------------
# API PÚBLICA — CONSULTAS
# ---------------------------------------------------------------------------

## Retorna true se o jogador possui ao menos uma unidade de nome_item.
func verificar_item(nome_item: String) -> bool:
	return _procurar_slot_com_item(nome_item) != -1


## Retorna o nome_item guardado em indice_slot, ou "" se o slot estiver
## vazio ou o índice for inválido.
func obter_item_por_slot(indice_slot: int) -> String:
	if not _indice_slot_e_valido(indice_slot):
		push_warning("InventoryManager: índice de slot inválido '%d'." % indice_slot)
		return ""

	var item = _itens_por_slot[indice_slot]
	return item if item != null else ""


## Retorna o índice do primeiro slot vazio, ou -1 se não houver nenhum.
func procurar_slot_vazio() -> int:
	for indice in range(TOTAL_SLOTS):
		if _itens_por_slot[indice] == null:
			return indice
	return -1


## Retorna true se todos os slots estiverem ocupados.
func inventario_esta_cheio() -> bool:
	return procurar_slot_vazio() == -1


# ---------------------------------------------------------------------------
# API PÚBLICA — ATUALIZAÇÃO VISUAL (via sinais, sem depender de UI)
# ---------------------------------------------------------------------------

## Reemite o estado atual de um slot (item + ícone) via slot_atualizado,
## para que o HUD sincronize o TextureButton correspondente.
##
## DECISÃO DE DESIGN: o InventoryManager não guarda referência aos nós
## TextureButton (isso acoplaria o inventário à cena da UI). Em vez disso,
## ele resolve o ícone junto ao ItemDatabase e emite um sinal com os dados
## prontos; o HUD.gd é quem efetivamente faz `slot.texture_normal = icone`.
func atualizar_slot(indice_slot: int) -> void:
	if not _indice_slot_e_valido(indice_slot):
		push_warning("InventoryManager: não é possível atualizar slot inválido '%d'." % indice_slot)
		return

	var nome_item: String = obter_item_por_slot(indice_slot)
	var icone: Texture2D = null

	if not nome_item.is_empty():
		var dados_item: Dictionary = ItemDatabase.get_item(nome_item)
		icone = dados_item.get("icone", null)

	slot_atualizado.emit(indice_slot, nome_item, icone)


## Reemite o estado de todos os slots de uma vez (ex.: ao abrir a fase e
## sincronizar a UI recém-criada com o inventário já existente).
func atualizar_todos_os_slots() -> void:
	for indice in range(TOTAL_SLOTS):
		atualizar_slot(indice)


# ---------------------------------------------------------------------------
# HELPERS INTERNOS
# ---------------------------------------------------------------------------

## Verifica se um nome_item é válido, ou seja, se existe no ItemDatabase.
func _item_e_valido(nome_item: String) -> bool:
	if nome_item.is_empty():
		return false

	var dados_item: Dictionary = ItemDatabase.get_item(nome_item)
	return not dados_item.is_empty()


## Retorna o índice do slot que contém nome_item, ou -1 se não encontrado.
func _procurar_slot_com_item(nome_item: String) -> int:
	for indice in range(TOTAL_SLOTS):
		if _itens_por_slot[indice] == nome_item:
			return indice
	return -1


## Garante que o índice está dentro do intervalo válido de slots.
func _indice_slot_e_valido(indice_slot: int) -> bool:
	return indice_slot >= 0 and indice_slot < TOTAL_SLOTS
