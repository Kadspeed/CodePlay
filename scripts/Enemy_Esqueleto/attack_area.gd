extends Area2D

## Script auxiliar da Area_Ataque do Esqueleto.
##
## O player.gd detecta o ataque do inimigo através da HitboxArea dele
## (sinal "area_entered"), e quando encontra uma Area2D no grupo
## "enemies" com o método get_dano(), chama esse método para saber
## quanto de dano aplicar. Por isso este script só existe para expor
## get_dano() na própria Area_Ataque (o Esqueleto, script principal,
## continua controlando quando essa área fica "monitorable" ou não).
##
## CONFIGURAÇÃO NECESSÁRIA NO EDITOR:
## 1. Selecione o nó Area_Ataque (dentro do Esqueleto).
## 2. Aba Script -> anexe este arquivo (area_ataque_esqueleto.gd) a ela.
## 3. Aba Node -> Groups -> adicione o grupo "enemies" a este nó
##    (não ao Esqueleto inteiro, tem que ser na própria Area_Ataque).

func get_dano() -> int:
	var esqueleto := get_parent()
	if esqueleto and "dano_ataque" in esqueleto:
		return esqueleto.dano_ataque
	return 0
