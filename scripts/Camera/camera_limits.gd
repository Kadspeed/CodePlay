extends Node2D
class_name CameraLimits

## Coloque um nó com este script, chamado exatamente "CameraLimits",
## em cada fase (mesmo nível do SpawnPoint). Ajuste os 4 valores no
## Inspector para os limites do mapa dessa fase — os mesmos valores
## que você colocaria em Camera2D > Limits no editor.
##
## O GameManager lê esses valores ao carregar a fase e os aplica na
## Camera2D do Player, para que ela (e a detecção de queda, que
## depende de limit_bottom) sempre reflita a fase atual.

@export var limite_esquerdo: int = -10000000
@export var limite_superior: int = -10000000
@export var limite_direito: int = 10000000
@export var limite_inferior: int = 10000000
