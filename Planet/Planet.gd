class_name Planet
extends CSGSphere3D

@export var is_sun: bool = false

var velocity: Vector3 = Vector3.ZERO
var mass: float = 1
var planets: Array[Node] = []
var suns: Array[Node] = []
var handle_process: bool
var planet_interaction: bool
var rotation_speed: float
var paused: bool

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not handle_process or paused:
		return

	if is_sun:
		rotate_y(delta * rotation_speed)
		return
	
	var net_force: Vector3 = Vector3.ZERO
	for sun in suns:
		if not is_instance_of(sun, Planet):
			continue

		var distance: float = position.distance_to(sun.position)
		var force: float = (sun.mass * mass) / (distance * distance)
		net_force += force * delta * position.direction_to(sun.position)

	if planet_interaction:
		for planet in planets:
			if planet == self or not is_instance_of(planet, Planet):
				continue

			var distance: float = position.distance_to(planet.position)
			var force: float = (planet.mass * mass) / (distance * distance)
			net_force += force * delta * position.direction_to(planet.position)

	velocity += net_force
	position += velocity * delta
	rotate_y(delta * rotation_speed)

func to_float32_array() -> PackedFloat32Array:
	return PackedFloat32Array([mass, position.x, position.y, position.z, rotation.x, rotation.y, rotation.z, velocity.x, velocity.y, velocity.z])
