extends Node3D

var planet_scene: PackedScene = load("res://Planet/Planet.tscn")
@export_subgroup("Animation Settings")
@export var paused: bool = true
@export var use_compute_shader: bool = true
@export var planets_per_timeout: int = 1
@export var max_planets: int = 2000
@export var max_suns: int = 10
@export var initial_planets: int = 1000
@export_subgroup("Animation Parameters")
@export var planet_interaction: bool = true
@export var sun_interaction: bool = false
@export var rotation_speed: float = 1.0

# Compute shader related globals
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var bindings: Array[RDUniform]
var buffers: Array[RID]

const INVOCATION_SIZE: int = 8

func _ready():
	$Suns/Sun.set_instance_shader_parameter("color", Color(1., 0.2, 0.2))
	$Suns/Sun.rotation_speed = rotation_speed
	$Suns/Sun.is_sun = true
	$Suns/Sun.handle_process = not use_compute_shader
	$Suns/Sun.mass = 100000.
	$Suns/Sun.paused = paused

	for i in range(initial_planets):
		spawn_planet()
	
	if use_compute_shader:
		setup_compute_shader()

func _process(delta):
	if paused:
		return

	if use_compute_shader:
		update_compute_shader(delta)

	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if direction:
		$Suns/Sun.position.x += direction.x
		$Suns/Sun.position.y += direction.y

func _unhandled_input(event):
	if event.is_action_pressed("toggle_pause"):
		paused = not paused
		$Interface/Control/LabelContainer/SettingsContainer/UseComputeShader.focus_mode = Control.FOCUS_NONE
		$Interface/Control/LabelContainer/SettingsContainer/PlanetInteraction.focus_mode = Control.FOCUS_NONE
		$Interface.toggle_pause(paused)

		for planet in $Planets.get_children():
			planet.paused = paused

		for sun in $Suns.get_children():
			sun.paused = paused

func get_random_position() -> Vector3:
	return Vector3(0, randf_range(-20, 20), randf_range(400, 800))

func get_random_mass() -> float:
	return randf_range(80., 100.)

func spawn_planet() -> void:
	var planet = planet_scene.instantiate()

	planet.mass = get_random_mass()
	planet.position = get_random_position()
	planet.velocity = Vector3(planet.mass, 0, 0)
	planet.radius = planet.mass / 20.
	planet.is_sun = false
	planet.handle_process = not use_compute_shader
	planet.rotation_speed = rotation_speed
	planet.paused = paused

	planet.set_instance_shader_parameter("color", Color(randf(), randf(), randf()))
	planet.planets = $Planets.get_children()
	planet.suns = $Suns.get_children()

	$Planets.add_child(planet)

func _on_timer_timeout():
	if $Planets.get_child_count() >= max_planets:
		$Timer.stop()
		return

	$Interface.change_counter($Planets.get_child_count(), max_planets)

	for i in range(planets_per_timeout):
		spawn_planet()

func setup_compute_shader() -> void:
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://ComputeSpace.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)

	# planet_data is the data that will be passed to the compute shader
	# it keeps the data of all the planets in the scene.
	var planet_buffer := rd.storage_buffer_create(max_planets * 10 * 4)
	var planet_uniform := RDUniform.new()
	planet_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	planet_uniform.binding = 0
	planet_uniform.add_id(planet_buffer)

	# output_data is the data that will be read back from the compute shader.
	# it will keep the new data of all the planets in the scene.
	var output_buffer = rd.storage_buffer_create(max_planets * 10 * 4)
	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 1
	output_uniform.add_id(output_buffer)

	# sun_data is the data that will be passed to the compute shader
	# it keeps the data of the sun(s) in the scene.
	var sun_buffer = rd.storage_buffer_create(max_suns * 10 * 4)
	var sun_uniform := RDUniform.new()
	sun_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	sun_uniform.binding = 2
	sun_uniform.add_id(sun_buffer)

	# new_sun_data is the data that will be passed to the compute shader
	# it keeps the data of the sun(s) in the scene.
	var new_sun_buffer = rd.storage_buffer_create(max_suns * 10 * 4)
	var new_sun_uniform := RDUniform.new()
	new_sun_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	new_sun_uniform.binding = 3
	new_sun_uniform.add_id(new_sun_buffer)

	# param_data is the data that will be passed to the compute shader
	# it keeps various parameters that will be used in the shader
	var param_data := get_params()
	var param_bytes = param_data.to_byte_array()
	var param_buffer = rd.storage_buffer_create(param_bytes.size(), param_bytes)
	var param_uniform := RDUniform.new()
	param_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	param_uniform.binding = 4
	param_uniform.add_id(param_buffer)

	bindings = [planet_uniform, output_uniform, sun_uniform, new_sun_uniform, param_uniform]
	buffers = [planet_buffer, output_buffer, sun_buffer, new_sun_buffer, param_buffer]

	# Create a uniform set (the last parameter (the 0) needs to match the "set" in our shader file)
	uniform_set = rd.uniform_set_create(bindings, shader, 0)

	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader)


func update_compute_shader(delta: float = 0) -> void:

	# Update the planet_data
	var planet_data := get_planet_data()
	var planet_bytes := planet_data.to_byte_array()
	rd.buffer_update(buffers[0], 0, planet_bytes.size(), planet_bytes)
	rd.buffer_update(buffers[1], 0, planet_bytes.size(), planet_bytes)

	# Update the sun_data
	var sun_data := get_sun_data()
	var sun_bytes := sun_data.to_byte_array()
	rd.buffer_update(buffers[2], 0, sun_bytes.size(), sun_bytes)
	rd.buffer_update(buffers[3], 0, sun_bytes.size(), sun_bytes)

	# Update the param_data
	var params := get_params(delta)
	var params_bytes = params.to_byte_array()
	rd.buffer_update(buffers[4], 0, params_bytes.size(), params_bytes)

	# Bind the compute pipeline
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceil(float($Planets.get_child_count() + $Suns.get_child_count()) / INVOCATION_SIZE), 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the planet buffer
	var new_planet_bytes := rd.buffer_get_data(buffers[1])
	var new_planet_data := new_planet_bytes.to_float32_array()

	# Read back the data from the sun buffer
	var new_sun_bytes := rd.buffer_get_data(buffers[3])
	var new_sun_data := new_sun_bytes.to_float32_array()

	set_planet_data(new_planet_data)
	set_sun_data(new_sun_data)

func get_planet_data() -> PackedFloat32Array:
	var planet_data: PackedFloat32Array = []

	for planet in $Planets.get_children():
		var data: PackedFloat32Array = planet.to_float32_array()
		planet_data.append_array(data)
	
	return planet_data

func get_sun_data() -> PackedFloat32Array:
	var sun_data: PackedFloat32Array = []

	for sun in $Suns.get_children():
		var data: PackedFloat32Array = sun.to_float32_array()
		sun_data.append_array(data)
	
	return sun_data

func get_params(delta: float = 0) -> PackedFloat32Array:
	var param_data: PackedFloat32Array = []
	param_data.append_array([delta, planet_interaction, sun_interaction, rotation_speed, float($Planets.get_child_count()), float($Suns.get_child_count())])
	return param_data

func set_planet_data(data: PackedFloat32Array) -> void:
	for i in range($Planets.get_child_count()):
		var planet = $Planets.get_child(i)
		planet.mass = data[i * 10]
		planet.position.x = data[i * 10 + 1]
		planet.position.y = data[i * 10 + 2]
		planet.position.z = data[i * 10 + 3]
		planet.rotation.x = data[i * 10 + 4]
		planet.rotation.y = data[i * 10 + 5]
		planet.rotation.z = data[i * 10 + 6]
		planet.velocity.x = data[i * 10 + 7]
		planet.velocity.y = data[i * 10 + 8]
		planet.velocity.z = data[i * 10 + 9]

func set_sun_data(data: PackedFloat32Array) -> void:
	for i in range($Suns.get_child_count()):
		var sun = $Suns.get_child(i)
		sun.mass = data[i * 10]
		sun.position.x = data[i * 10 + 1]
		sun.position.y = data[i * 10 + 2]
		sun.position.z = data[i * 10 + 3]
		sun.rotation.x = data[i * 10 + 4]
		sun.rotation.y = data[i * 10 + 5]
		sun.rotation.z = data[i * 10 + 6]
		sun.velocity.x = data[i * 10 + 7]
		sun.velocity.y = data[i * 10 + 8]
		sun.velocity.z = data[i * 10 + 9]


func _on_interface_use_compute_shader_changed(toggled_on: bool) -> void:
	self.use_compute_shader = toggled_on
	self.update_planets()

func _on_interface_planet_interaction_changed(toggled_on) -> void:
	self.planet_interaction = toggled_on
	self.update_planets()

func update_planets() -> void:
	for planet in $Planets.get_children():
		planet.handle_process = not self.use_compute_shader
		planet.planet_interaction = self.planet_interaction
	for planet in $Suns.get_children():
		planet.handle_process = not self.use_compute_shader
