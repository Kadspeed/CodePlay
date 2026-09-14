# scripts/slot_codigo.gd
extends Control

# ============ SINAIS ============
# 🔥 REMOVIDOS: bloco_inserido e bloco_removido não são usados pelo Puzzle
# O Puzzle controla tudo via clique nos blocos

# ============ VARIÁVEIS ============
var bloco_atual: Node = null

# ============ NÓS ============
@onready var texture_rect: TextureRect = $TextureRect

# ============ INICIALIZAÇÃO ============
func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	
	if texture_rect:
		texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	
	custom_minimum_size = Vector2(100, 60)
	
	print("✅ Slot pronto: ", name)

# ============ FUNÇÕES PÚBLICAS ============

func colocar_bloco(bloco: Node) -> bool:
	if not bloco or not is_instance_valid(bloco):
		print("⚠️ Tentando colocar bloco inválido no slot ", name)
		return false
	
	if bloco_atual and is_instance_valid(bloco_atual):
		_remover_bloco_interno()
	
	if bloco.get_parent() == self:
		print("⚠️ Bloco já está no slot ", name)
		return true
	
	if bloco.get_parent():
		bloco.get_parent().remove_child(bloco)
	
	add_child(bloco)
	bloco.position = Vector2.ZERO
	
	bloco_atual = bloco
	
	print("✅ Bloco ", bloco.name, " colocado no slot ", name)
	
	# 🔥 REMOVIDO: bloco_inserido.emit(self, bloco)
	
	return true

func _remover_bloco_interno() -> Node:
	if not bloco_atual or not is_instance_valid(bloco_atual):
		return null
	
	var bloco_que_saiu = bloco_atual
	
	if bloco_que_saiu.get_parent() == self:
		remove_child(bloco_que_saiu)
	elif bloco_que_saiu.get_parent():
		bloco_que_saiu.get_parent().remove_child(bloco_que_saiu)
	
	bloco_atual = null
	
	return bloco_que_saiu

func remover_bloco() -> Node:
	var bloco_que_saiu = _remover_bloco_interno()
	
	if bloco_que_saiu:
		print("✅ Bloco ", bloco_que_saiu.name, " removido do slot ", name)
		# 🔥 REMOVIDO: bloco_removido.emit(self, bloco_que_saiu)
	
	return bloco_que_saiu

func get_bloco() -> Node:
	return bloco_atual

func esta_livre() -> bool:
	return bloco_atual == null or not is_instance_valid(bloco_atual)

func esta_ocupado() -> bool:
	return not esta_livre()

func limpar_slot():
	if bloco_atual and is_instance_valid(bloco_atual):
		if bloco_atual.get_parent() == self:
			remove_child(bloco_atual)
		elif bloco_atual.get_parent():
			bloco_atual.get_parent().remove_child(bloco_atual)
		
		bloco_atual = null
		print("✅ Slot ", name, " limpo")

# ============ DEBUG ============
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if not texture_rect:
		warnings.append("TextureRect não encontrado!")
	
	return warnings
