extends CanvasLayer

signal use_compute_shader_changed(toggled_on: bool)
signal planet_interaction_changed(toggled_on: bool)

const FPS_EXPRESSION = "FPS: %d"

func change_counter(num: int, max_num: int) -> void:
	$Control/LabelContainer/PlanetCounter.text = str(num) + " / " + str(max_num)

func _process(_delta):
	var fps = Engine.get_frames_per_second()
	$Control/LabelContainer/FPSLabel.text = FPS_EXPRESSION % int(fps)

func toggle_pause(paused: bool) -> void:
	$Control/LabelContainer/PausedLabel.text = "Paused" if paused else "Resumed"

func _on_use_compute_shader_toggled(toggled_on:bool):
	# Use compute shader button is toggled
	use_compute_shader_changed.emit(toggled_on)


func _on_planet_interaction_toggled(toggled_on:bool):
	# Planet interaction button is toggled
	planet_interaction_changed.emit(toggled_on)
