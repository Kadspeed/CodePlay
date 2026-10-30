extends Node
## Estado mínimo que sobrevive à troca completa de cenas.

var fase_para_reiniciar: int = 0
var ignorar_modo_desenvolvedor_uma_vez: bool = false


func preparar_reinicio(fase_id: int) -> void:
	fase_para_reiniciar = maxi(fase_id, 1)
	ignorar_modo_desenvolvedor_uma_vez = false


func consumir_fase_reinicio() -> int:
	var fase: int = fase_para_reiniciar
	fase_para_reiniciar = 0
	return fase


func preparar_retorno_menu() -> void:
	fase_para_reiniciar = 0
	ignorar_modo_desenvolvedor_uma_vez = true


func consumir_bloqueio_modo_desenvolvedor() -> bool:
	var bloquear: bool = ignorar_modo_desenvolvedor_uma_vez
	ignorar_modo_desenvolvedor_uma_vez = false
	return bloquear
