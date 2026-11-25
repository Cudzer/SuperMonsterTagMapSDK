extends CanvasLayer
## Stands in for the game's Transition autoload in the Map SDK: the teleporter blinks the screen in
## game. Here a blink just does its work.


func blink(on_covered: Callable, _center: Vector2 = Vector2(-1, -1)) -> void:
	on_covered.call()
