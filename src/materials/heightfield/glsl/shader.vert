#define LOD

varying vec3 vViewPosition;

#include <common>
#include <color_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <lod_pars_vertex>

void main() {

	#include <color_vertex>

	#include <begin_vertex>
	#include <lod_vertex>
	#include <logdepthbuf_vertex>

	vViewPosition = -mvPosition.xyz;

	#include <shadowmap_vertex>

}