#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

// I tried using 2 vec3s and a float, but it didn't work. If I get it to work, I'll
// try using a better data structure.
struct Planet {
	float data[7];
};

layout(std430, set = 0, binding = 0) buffer PlanetData {
	Planet planets[];
	// float planet_data[];
} planets;

void main() {
	if (gl_GlobalInvocationID.x >= planets.planets.length()) {
		return;
	}
	Planet planet = planets.planets[gl_GlobalInvocationID.x];
	planet.data[0] = planet.data[0] + 1.0;
	planet.data[1] = planet.data[1] + 1.0;
	planet.data[2] = planet.data[2] + 1.0;
	planet.data[3] = planet.data[3] + 1.0;
	planet.data[4] = planet.data[4] + 1.0;
	planet.data[5] = planet.data[5] + 1.0;
	planet.data[6] = planet.data[6] + 1.0;
	planets.planets[gl_GlobalInvocationID.x] = planet;
}
