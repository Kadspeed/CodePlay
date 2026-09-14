# scripts/puzzle_variaveis.gd
extends Control

# ============================================================
# 1. SINAIS
# ============================================================

signal puzzle_completado()
signal puzzle_resetado()
signal desafio_concluido()

# ============================================================
# 2. NÓS
# ============================================================

@onready var blocos_container: Control = $AreaBlocos
@onready var slots_container: Control = $AreaMontagem
@onready var botao_executar: Button = $BotaoExecutar
@onready var botao_limpar: Button = $BotaoLimpar
@onready var feedback_label: Label = $Feedback

# ============================================================
# 3. CONFIGURAÇÃO DO PUZZLE
# ============================================================

var respostas_corretas: Array = ["LET test = 10", "LET test = \"Test\""]
var ordem_original_blocos: Array = []
var desafio_resolvido: bool = false

# ============================================================
# 4. CONFIGURAÇÃO DOS BLOCOS
# ============================================================

var config_blocos = [
	{"nome": "Bloco1", "tipo": "sintaxe", "texto": "LET test", "valor": "LET test"},
	{"nome": "Bloco2", "tipo": "sintaxe", "texto": "LET 1test", "valor": "LET 1test"},
	{"nome": "Bloco3", "tipo": "sintaxe", "texto": "VAR test", "valor": "VAR test"},
	{"nome": "Bloco4", "tipo": "operador", "texto": "=", "valor": "="},
	{"nome": "Bloco5", "tipo": "operador", "texto": "+", "valor": "+"},
	{"nome": "Bloco6", "tipo": "operador", "texto": ";", "valor": ";"},
	{"nome": "Bloco7", "tipo": "valor", "texto": "10", "valor": "10"},
	{"nome": "Bloco8", "tipo": "valor", "texto": "\"Test\"", "valor": "\"Test\""},
	{"nome": "Bloco9", "tipo": "valor", "texto": "@", "valor": "@"}
]

# ============================================================
# 5. INICIALIZAÇÃO
# ============================================================

func _ready():
	print("🔧 ===== INICIANDO PUZZLE =====")
	print("📝 Respostas corretas: ", respostas_corretas)
	
	_configurar_botoes()
	_configurar_blocos()
	_configurar_slots()
	_conectar_blocos()
	
	_mostrar_feedback("Clique em um bloco para colocá-lo no slot", Color.WHITE)
	print("✅ Puzzle_Variaveis pronto!")

# ============================================================
# 6. CONFIGURAÇÕES
# ============================================================

func _configurar_botoes():
	if botao_executar:
		botao_executar.mouse_filter = Control.MOUSE_FILTER_STOP
		botao_executar.disabled = false
		if not botao_executar.pressed.is_connected(_on_botao_executar_pressed):
			botao_executar.pressed.connect(_on_botao_executar_pressed)
			print("✅ BotaoExecutar conectado")
	
	if botao_limpar:
		botao_limpar.mouse_filter = Control.MOUSE_FILTER_STOP
		botao_limpar.disabled = false
		if not botao_limpar.pressed.is_connected(_on_botao_limpar_pressed):
			botao_limpar.pressed.connect(_on_botao_limpar_pressed)
			print("✅ BotaoLimpar conectado")

func _configurar_blocos():
	if not blocos_container:
		print("⚠️ BlocosContainer não encontrado!")
		return
	
	ordem_original_blocos.clear()
	
	for config in config_blocos:
		var bloco = _encontrar_bloco_por_nome(config["nome"])
		
		if bloco:
			if bloco.has_method("definir_tipo"):
				bloco.definir_tipo(config["tipo"])
			
			if bloco.has_method("definir_valor"):
				bloco.definir_valor(config["valor"])
			
			if bloco.has_method("definir_texto"):
				bloco.definir_texto(config["texto"])
			
			if "valor_bloco" in bloco:
				bloco.valor_bloco = config["valor"]
			if "texto_bloco" in bloco:
				bloco.texto_bloco = config["texto"]
			
			ordem_original_blocos.append({
				"bloco": bloco,
				"posicao": bloco.position
			})
			
			print("✅ Bloco configurado: ", config["nome"], " (", config["valor"], ")")
		else:
			print("⚠️ Bloco não encontrado: ", config["nome"])

func _encontrar_bloco_por_nome(nome: String) -> Node:
	if not blocos_container:
		return null
	
	for bloco in blocos_container.get_children():
		if bloco.name == nome:
			return bloco
	
	return null

func _configurar_slots():
	if not slots_container:
		print("⚠️ SlotsContainer não encontrado!")
		return
	
	for slot in slots_container.get_children():
		if slot.has_method("set_tipo_aceito"):
			slot.set_tipo_aceito("qualquer")
		print("✅ Slot configurado: ", slot.name)

func _conectar_blocos():
	if not blocos_container:
		return
	
	var blocos_conectados = 0
	
	for bloco in blocos_container.get_children():
		if bloco.has_signal("bloco_clicado"):
			if bloco.bloco_clicado.is_connected(_on_bloco_clicado):
				bloco.bloco_clicado.disconnect(_on_bloco_clicado)
			
			bloco.bloco_clicado.connect(_on_bloco_clicado)
			blocos_conectados += 1
			print("✅ Bloco conectado: ", bloco.name)
	
	print("📊 Total de blocos conectados: ", blocos_conectados)

# ============================================================
# 7. LÓGICA DE CLIQUE NOS BLOCOS
# ============================================================

func _on_bloco_clicado(bloco: Node):
	if desafio_resolvido:
		_mostrar_feedback("Puzzle já foi resolvido! Clique em Limpar para recomeçar.", Color.YELLOW)
		return
	
	if not is_instance_valid(bloco):
		print("⚠️ Bloco inválido!")
		return
	
	if _bloco_esta_em_slot(bloco):
		print("ℹ️ Bloco já está em um slot: ", bloco.name)
		_mostrar_feedback("Este bloco já está em um slot!", Color.YELLOW)
		return
	
	var slot_vazio = _procurar_primeiro_slot_vazio()
	
	if slot_vazio:
		_colocar_bloco_no_slot(slot_vazio, bloco)
		print("✅ Bloco ", bloco.name, " colocado no slot ", slot_vazio.name)
		
		if _todos_slots_preenchidos():
			_mostrar_feedback("Todos os slots preenchidos! Clique em Executar.", Color.GREEN)
	else:
		_mostrar_feedback("Todos os espaços já estão preenchidos.", Color.YELLOW)
		print("⚠️ Todos os slots estão ocupados!")

# ============================================================
# 8. MANIPULAÇÃO DE SLOTS
# ============================================================

func _bloco_esta_em_slot(bloco: Node) -> bool:
	if not slots_container:
		return false
	
	for slot in slots_container.get_children():
		if slot.has_method("get_bloco"):
			var bloco_no_slot = slot.get_bloco()
			if bloco_no_slot == bloco:
				return true
	
	return false

func _procurar_primeiro_slot_vazio() -> Node:
	if not slots_container:
		return null
	
	for slot in slots_container.get_children():
		if slot.has_method("esta_livre") and slot.esta_livre():
			return slot
	
	return null

func _colocar_bloco_no_slot(slot: Node, bloco: Node):
	if not slot or not bloco:
		return
	
	if slot.has_method("colocar_bloco"):
		var sucesso = slot.colocar_bloco(bloco)
		if sucesso:
			if bloco.has_method("resetar_visual"):
				bloco.resetar_visual()
			_mostrar_feedback("✅ Bloco colocado em " + slot.name, Color.GREEN)
		else:
			_mostrar_feedback("❌ Erro ao colocar bloco!", Color.RED)

func _todos_slots_preenchidos() -> bool:
	if not slots_container:
		return false
	
	for slot in slots_container.get_children():
		if slot.has_method("esta_livre") and slot.esta_livre():
			return false
	
	return true

func _contar_slots_preenchidos() -> int:
	if not slots_container:
		return 0
	
	var count = 0
	for slot in slots_container.get_children():
		if slot.has_method("esta_livre") and not slot.esta_livre():
			count += 1
	
	return count

# ============================================================
# 9. MONTAGEM E VALIDAÇÃO DA RESPOSTA
# ============================================================

func _montar_resposta() -> String:
	var partes = []
	
	if not slots_container:
		return ""
	
	print("🔍 Montando resposta...")
	
	for slot in slots_container.get_children():
		var bloco = null
		if slot.has_method("get_bloco"):
			bloco = slot.get_bloco()
		
		if bloco and is_instance_valid(bloco):
			var valor = _obter_valor_bloco(bloco)
			partes.append(valor)
			print("  Slot ", slot.name, " → '", valor, "'")
		else:
			partes.append("[vazio]")
			print("  Slot ", slot.name, " → [vazio]")
	
	var resposta = " ".join(partes)
	print("📝 Resposta montada: '", resposta, "'")
	return resposta

func _obter_valor_bloco(bloco: Node) -> String:
	if bloco.has_method("get_valor"):
		return bloco.get_valor()
	if bloco.has_method("get_texto"):
		return bloco.get_texto()
	
	for child in bloco.get_children():
		if child is Label:
			return child.text
	
	return bloco.name

func _validar_resposta() -> bool:
	print("🔍 ===== VALIDANDO RESPOSTA =====")
	
	if not slots_container:
		return false
	
	if not _todos_slots_preenchidos():
		var preenchidos = _contar_slots_preenchidos()
		var total = slots_container.get_children().size()
		_mostrar_feedback("⚠️ Complete todos os espaços! (" + str(preenchidos) + "/" + str(total) + ")", Color.YELLOW)
		return false
	
	var resposta = _montar_resposta()
	var resposta_normalizada = _normalizar_string(resposta)
	
	print("📝 Resposta normalizada: '", resposta_normalizada, "'")
	print("📝 Respostas corretas: ", respostas_corretas)
	
	for resposta_correta in respostas_corretas:
		var resposta_correta_normalizada = _normalizar_string(resposta_correta)
		if resposta_normalizada == resposta_correta_normalizada:
			print("✅ MATCH com: '", resposta_correta, "'")
			return true
		else:
			print("❌ Não match com: '", resposta_correta, "'")
	
	return false

func _normalizar_string(texto: String) -> String:
	var normalizado = texto.strip_edges()
	normalizado = normalizado.replace("  ", " ")
	normalizado = normalizado.replace("“", "\"").replace("”", "\"")
	normalizado = normalizado.replace("'", "\"")
	return normalizado

# ============================================================
# 10. BOTÕES EXECUTAR E LIMPAR
# ============================================================

func _on_botao_executar_pressed():
	print("🔘 ===== BOTAO EXECUTAR PRESSIONADO =====")
	
	if desafio_resolvido:
		_mostrar_feedback("Puzzle já foi resolvido! Clique em Limpar para recomeçar.", Color.YELLOW)
		return
	
	if _validar_resposta():
		_mostrar_feedback("🎉 Parabéns! Resposta correta!", Color.GREEN)
		desafio_resolvido = true
		
		if botao_executar:
			botao_executar.disabled = true
		
		print("🎉 Puzzle completado!")
		
		# 🔥 EMITIR SINAL DESAFIO_CONCLUIDO
		# O GameManager escuta este sinal e gerencia o fechamento
		puzzle_completado.emit()
		desafio_concluido.emit()
		
		# 🔥 O PUZZLE NÃO SE FECHA SOZINHO
		# O GameManager é responsável por remover o puzzle da cena
	else:
		_mostrar_feedback("❌ Resposta incorreta. Tente novamente.", Color.RED)
		print("❌ Resposta incorreta!")

func _on_botao_limpar_pressed():
	print("🔘 ===== BOTAO LIMPAR PRESSIONADO =====")
	
	_limpar_puzzle()
	_mostrar_feedback("🔄 Puzzle reiniciado. Clique em um bloco para colocá-lo no slot.", Color.WHITE)

# ============================================================
# 11. LIMPEZA E RESET
# ============================================================

func _limpar_puzzle():
	print("🔄 ===== LIMPANDO PUZZLE =====")
	
	var blocos_para_devolver = []
	
	if slots_container:
		print("📋 Coletando blocos dos slots...")
		for slot in slots_container.get_children():
			if slot.has_method("get_bloco"):
				var bloco = slot.get_bloco()
				if bloco and is_instance_valid(bloco):
					print("  ✅ Bloco encontrado no slot ", slot.name, ": ", bloco.name)
					
					if slot.has_method("remover_bloco"):
						slot.remover_bloco()
						print("  ✅ Removido via remover_bloco()")
					
					blocos_para_devolver.append(bloco)
					print("  📌 Adicionado à lista de devolução")
	
	print("📊 Total de blocos para devolver: ", blocos_para_devolver.size())
	
	for bloco in blocos_para_devolver:
		if is_instance_valid(bloco):
			_devolver_bloco_ao_container(bloco)
	
	desafio_resolvido = false
	
	if botao_executar:
		botao_executar.disabled = false
	
	print("🔄 Puzzle resetado!")
	puzzle_resetado.emit()

func _devolver_bloco_ao_container(bloco: Node):
	if not is_instance_valid(bloco):
		print("⚠️ Tentando devolver bloco inválido!")
		return
	
	print("↩️ Devolvendo bloco: ", bloco.name)
	
	var pai_atual = bloco.get_parent()
	if pai_atual:
		pai_atual.remove_child(bloco)
		print("  ✅ Removido do pai: ", pai_atual.name)
	
	if bloco.has_method("resetar_visual"):
		bloco.resetar_visual()
	
	if blocos_container and bloco.get_parent() == blocos_container:
		print("  ⚠️ Bloco já está no container!")
		return
	
	var pos_original = null
	for item in ordem_original_blocos:
		if item["bloco"] == bloco:
			pos_original = item["posicao"]
			print("  ✅ Posição original encontrada: ", pos_original)
			break
	
	if blocos_container and is_instance_valid(blocos_container):
		blocos_container.add_child(bloco)
		
		if pos_original != null:
			bloco.position = pos_original
			print("  ✅ Posição restaurada: ", pos_original)
		else:
			bloco.position = Vector2.ZERO
			print("  ⚠️ Posição definida como ZERO (fallback)")

# ============================================================
# 12. FEEDBACK
# ============================================================

func _mostrar_feedback(texto: String, cor: Color):
	if feedback_label:
		feedback_label.text = texto
		feedback_label.modulate = cor
		print("📢 Feedback: ", texto)

# ============================================================
# 13. FUNÇÕES PÚBLICAS
# ============================================================

func definir_resposta_correta(resposta: String):
	respostas_corretas = [resposta]
	print("📝 Resposta correta definida: ", resposta)

func definir_respostas_corretas(novas_respostas: Array):
	respostas_corretas = novas_respostas
	print("📝 Respostas corretas atualizadas: ", respostas_corretas)

func configurar_novo_desafio(nova_config_blocos: Array, nova_resposta):
	if typeof(nova_resposta) == TYPE_STRING:
		respostas_corretas = [nova_resposta]
	elif typeof(nova_resposta) == TYPE_ARRAY:
		respostas_corretas = nova_resposta
	
	config_blocos = nova_config_blocos
	desafio_resolvido = false
	
	if botao_executar:
		botao_executar.disabled = false
	
	_limpar_puzzle()
	_configurar_blocos()
	_configurar_slots()
	_conectar_blocos()
	
	_mostrar_feedback("Novo desafio carregado!", Color.CYAN)
	print("📚 Novo desafio configurado!")

func get_slots() -> Array:
	var slots = []
	if slots_container:
		for slot in slots_container.get_children():
			slots.append(slot)
	return slots

func get_blocos() -> Array:
	var blocos = []
	if blocos_container:
		for bloco in blocos_container.get_children():
			blocos.append(bloco)
	return blocos

func get_resposta_jogador() -> String:
	return _montar_resposta()

func is_puzzle_completo() -> bool:
	return desafio_resolvido

func get_feedback_text() -> String:
	return feedback_label.text if feedback_label else ""

func get_respostas_corretas() -> Array:
	return respostas_corretas

func resetar_puzzle():
	_limpar_puzzle()
	_mostrar_feedback("Puzzle reiniciado.", Color.WHITE)

# ============================================================
# 14. FUNÇÕES DE DEBUG - REMOVIDAS COMPLETAMENTE
# ============================================================

# 🔥 FUNÇÃO REMOVIDA: _input()
# O puzzle NÃO deve ser fechado com ESC.
# O fechamento é feito exclusivamente pelo GameManager
# após receber o sinal desafio_concluido.

# A função _input() foi completamente removida para evitar
# que o jogador feche o puzzle manualmente.
