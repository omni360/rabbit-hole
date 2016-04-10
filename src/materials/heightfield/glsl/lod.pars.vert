uniform sampler2D heightMap;

uniform int level;
uniform int morphingLevels;
uniform float scale;
uniform float heightScale;

uniform vec3 planeUp;
uniform vec3 planeAt;
uniform vec3 planePoint;

uniform vec2 texelSize;

varying vec3 vWorldPosition;

#ifndef FLAT_SHADED

	varying vec3 vNormal;

#endif

const int MAX_MORPHING_LEVELS = 2;

vec2 computeAncestorMorphing(int morphLevel, vec2 gridPosition, float heightMorphFactor, vec3 cameraScaledPosition, vec2 previousMorphing) {

	float morphLevelFloat = float(morphLevel);

	// Check if it's necessary to apply the morphing (on 1 square on 2).
	vec2 fractional = gridPosition * RESOLUTION * 0.5;

	if(morphLevel > 1) {

		fractional = (fractional + 0.5) / pow(2.0, morphLevelFloat - 1.0);

	}

	fractional -= floor(fractional);

	// Compute morphing factors based on the height and the parent LOD.
	vec2 squareOffset = abs(cameraScaledPosition.xz - (gridPosition + previousMorphing)) / morphLevelFloat;
	vec2 comparePos = max(vec2(0.0), squareOffset * 4.0 - 1.0);
	float parentMorphFactor = min(1.0, max(comparePos.x, comparePos.y));

	// Compute the composition of morphing factors.
	vec2 morphFactor = vec2(0.0);

	if(fractional.x + fractional.y > 0.49) {

		float morphing = parentMorphFactor;

		// If first LOD, apply the height morphing factor everywhere.
		if(level + morphLevel == 1) {

			morphing = max(heightMorphFactor, morphing);

		}

		morphFactor += morphing * floor(fractional * 2.0);

	}

	return morphLevelFloat * morphFactor / RESOLUTION;

}

vec4 computePosition(vec3 position) {

	#ifdef USE_PLANE_PARAMETERS

		// Compute the plane rotation if needed.
		mat3 planeRotation;
		vec3 planeY = normalize(planeUp);
		vec3 planeZ = normalize(planeAt);
		vec3 planeX = normalize(cross(planeY, planeZ));
		planeZ = normalize(cross(planeY, planeX));
		planeRotation = mat3(planeX, planeY, planeZ);

	#endif

	// Project the camera position and the scene origin on the grid.
	vec3 projectedCamera = vec3(cameraPosition.x, 0.0, cameraPosition.z);

	#ifdef USE_PLANE_PARAMETERS

		projectedCamera = cameraPosition - dot(cameraPosition - planePoint, planeY) * planeY;
		vec3 projectedOrigin = -dot(-planePoint, planeY) * planeY;

	#endif

	// Discretise the space and make the grid following the camera.
	float cameraHeightLog = log2(length(cameraPosition - projectedCamera));
	float s = scale * pow(2.0, floor(cameraHeightLog)) * 0.005;
	vec3 cameraScaledPosition = projectedCamera / s;

	#ifdef USE_PLANE_PARAMETERS

		cameraScaledPosition = cameraScaledPosition * planeRotation;

	#endif

	vec2 gridPosition = position.xz + floor(cameraScaledPosition.xz * RESOLUTION + 0.5) / RESOLUTION;

	// Compute the height morphing factor.
	float heightMorphFactor = cameraHeightLog - floor(cameraHeightLog);
		
	// Compute morphing factors from LOD ancestors.
	vec2 morphing = vec2(0.0);

	for(int i = 1; i <= MAX_MORPHING_LEVELS; ++i) {

		if(i <= morphingLevels) {

			morphing += computeAncestorMorphing(i, gridPosition, heightMorphFactor, cameraScaledPosition, morphing);

		}

	}

	// Apply final morphing.
	gridPosition = gridPosition + morphing;

	// Compute world coordinates.
	vec3 worldPosition = vec3(gridPosition.x * s, 0.0, gridPosition.y * s);

	#ifdef USE_PLANE_PARAMETERS

		worldPosition = planeRotation * worldPosition + projectedOrigin;

	#endif

	return vec4(worldPosition, 1.0);

}

vec4 getHeightInfo(vec2 coord) {

	float height = texture2D(heightMap, coord).x;

	float s0 = texture2D(heightMap, coord + vec2(-texelSize.x, 0.0)).x;
	float s1 = texture2D(heightMap, coord + vec2(texelSize.x, 0.0)).x;
	float s2 = texture2D(heightMap, coord + vec2(0.0, -texelSize.y)).x;
	float s3 = texture2D(heightMap, coord + vec2(0.0, texelSize.y)).x;

	vec3 va = normalize(vec3(2.0, 0.0, s1 - s0));
	vec3 vb = normalize(vec3(0.0, 2.0, s3 - s2));

	return vec4(cross(va, vb).yzx, height);

}