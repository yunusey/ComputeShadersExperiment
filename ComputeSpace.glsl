#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

// I tried using 2 vec3s and a float, but it didn't work. If I get it to work, I'll
// try using a better data structure.
// data[0] = mass
// data[1:3] = position
// data[4:6] = rotation
// data[7:10] = velocity
struct PlanetData {
	float data[10];
};

// Given planet data
layout(set = 0, binding = 0, std430) restrict buffer PlanetDataBuffer {
	PlanetData planets[];
}
planets;

// Computed planet data
layout(set = 0, binding = 1, std430) restrict buffer NewPlanetDataBuffer {
	PlanetData new_planet_data[];
}
new_planet_data;

layout(set = 0, binding = 2, std430) restrict buffer SunDataBuffer {
	PlanetData sun_data[];
}
suns;

layout(set = 0, binding = 3, std430) restrict buffer NewSunDataBuffer {
	PlanetData sun_data[];
}
new_sun_data;

// Delta time
layout(set = 0, binding = 4, std430) restrict buffer ParamsBuffer {
	float delta;
	bool planet_interaction;
	bool sun_interaction;
	float rotation_speed;
	float num_planets;
	float num_suns;
}
params;

struct Planet {
	float mass;
	vec3 position;
	vec3 rotation;
	vec3 velocity;
};

Planet create_planet(float mass, vec3 position, vec3 rotation, vec3 velocity) {
	Planet planet;
	planet.mass = mass;
	planet.position = position;
	planet.rotation = rotation;
	planet.velocity = velocity;
	return planet;
}

Planet get_planet_from_data(PlanetData planet_data) {
	float data[10] = planet_data.data;
	Planet planet = create_planet(data[0], vec3(data[1], data[2], data[3]), vec3(data[4], data[5], data[6]), vec3(data[7], data[8], data[9]));
	return planet;
}

PlanetData get_planet_data_from_planet(Planet planet) {
	PlanetData planet_data;
	planet_data.data[0] = planet.mass;
	planet_data.data[1] = planet.position.x;
	planet_data.data[2] = planet.position.y;
	planet_data.data[3] = planet.position.z;
	planet_data.data[4] = planet.rotation.x;
	planet_data.data[5] = planet.rotation.y;
	planet_data.data[6] = planet.rotation.z;
	planet_data.data[7] = planet.velocity.x;
	planet_data.data[8] = planet.velocity.y;
	planet_data.data[9] = planet.velocity.z;
	return planet_data;
}

vec3 get_net_force(Planet planet, Planet other_planet) {
	vec3 net_force = vec3(0., 0., 0.);
	float distance = length(planet.position - other_planet.position);
	if (distance == 0.) return net_force;
	float force = (planet.mass * other_planet.mass) / (distance * distance);
	return normalize(other_planet.position - planet.position) * force;
}

void main() {
	if (gl_GlobalInvocationID.x < uint(params.num_planets)) {
		// Set new planet data for the given planet index.

		PlanetData planet_data = planets.planets[gl_GlobalInvocationID.x];
		Planet planet = get_planet_from_data(planet_data);
		vec3 net_force = vec3(0., 0., 0.);

		if (params.planet_interaction) {
			for (int i = 0; i < params.num_planets; i++) {
				if (i == gl_GlobalInvocationID.x) continue;
				Planet other_planet = get_planet_from_data(planets.planets[i]);
				net_force += get_net_force(planet, other_planet) * params.delta;
			}
		}

		for (int i = 0; i < params.num_suns; i++) {
			Planet sun = get_planet_from_data(suns.sun_data[i]);
			net_force += get_net_force(planet, sun) * params.delta;
		}

		float mass = planet.mass;
		vec3 velocity = planet.velocity + net_force;
		vec3 position = planet.position + velocity * params.delta;
		vec3 rotation = planet.rotation + vec3(0., params.rotation_speed * params.delta, 0.);

		planet = create_planet(mass, position, rotation, velocity);
		planet_data = get_planet_data_from_planet(planet);
		new_planet_data.new_planet_data[gl_GlobalInvocationID.x] = planet_data;
	}
	else if (gl_GlobalInvocationID.x - uint(params.num_planets) < uint(params.num_suns)) {
		// Set new sun data for the given sun index.
		uint sun_index = gl_GlobalInvocationID.x - uint(params.num_planets);
		PlanetData sun_data = suns.sun_data[sun_index];
		Planet sun = get_planet_from_data(sun_data);

		vec3 net_force = vec3(0., 0., 0.);

		if (params.sun_interaction) {
			for (int i = 0; i < params.num_suns; i++) {
				Planet other_sun = get_planet_from_data(suns.sun_data[i]);
				net_force += get_net_force(sun, other_sun);
			}
		}

		float mass = sun.mass;
		vec3 velocity = sun.velocity + (net_force) * params.delta;
		vec3 position = sun.position + velocity * params.delta;
		vec3 rotation = sun.rotation + vec3(0., params.rotation_speed * params.delta, 0.);

		sun = create_planet(mass, position, rotation, velocity);
		sun_data = get_planet_data_from_planet(sun);
		new_sun_data.sun_data[sun_index] = sun_data;
	}
}
