extends Node3D

func _ready():
	var rd := RenderingServer.create_local_rendering_device()

	# Load GLSL shader
	var shader_file := load("res://TestComputeShader/test.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	# Prepare our data. We use floats in the shader, so we need 32 bit.
	var input := get_input_data()
	var input_bytes := input.to_byte_array()

	# Create a storage buffer that can hold our float values.
	var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)

	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)

	var uniform_set := rd.uniform_set_create([uniform], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(buffer)
	var output := output_bytes.to_float32_array()
	print("Input: ", input)
	print("Output: ", output)

func get_input_data() -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for i in $Planets.get_children():
		# data.append_array(i.to_float32_array())
		data.append_array(PackedFloat32Array([i.position.x, i.position.y, i.position.z]))
		data.append_array(PackedFloat32Array([i.velocity.x, i.velocity.y, i.velocity.z]))
		data.append(i.mass)
	return data
