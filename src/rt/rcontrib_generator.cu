/*
 *  rcontrib_generator.cu - entry point for contribution coefficient calculation on GPUs.
 */

#include "accelerad_copyright.h"

#include <optix_world.h>
#include "optix_shader_ray.h"
#ifdef CONTRIB_DOUBLE
#include "optix_double.h"
#endif

using namespace optix;

/* Program variables */
rtDeclareVariable(unsigned int, do_irrad, , ) = 0u; /* Calculate irradiance (-i) */

/* Contex variables */
rtBuffer<float3, 2>              origin_buffer;
rtBuffer<float3, 2>              direction_buffer;
rtBuffer<contrib4, 3>            contrib_buffer;
#ifdef RAY_COUNT
rtBuffer<unsigned int, 2>        ray_count_buffer;
#endif
rtDeclareVariable(rtObject, top_object, , );
rtDeclareVariable(rtObject, top_irrad, , );
rtDeclareVariable(unsigned int, imm_irrad, , ) = 0u; /* Immediate irradiance (-I) */
rtDeclareVariable(unsigned int, lim_dist, , ) = 0u; /* Limit ray distance (-ld) */
rtDeclareVariable(unsigned int, contrib_segment, , ) = 0u; /* Start row for large outputs */

/* OptiX variables */
rtDeclareVariable(uint2, launch_index, rtLaunchIndex, );
rtDeclareVariable(uint2, launch_dim, rtLaunchDim, );


RT_PROGRAM void ray_generator()
{
	const uint2 index = make_uint2(launch_index.x, launch_index.y + contrib_segment);
	PerRayData_radiance prd;
	init_rand(&prd.state, index.x + launch_dim.x * index.y);
	prd.result = make_float3(0.0f); // Probably not necessary
	prd.weight = 1.0f;
	prd.depth = 0;
	prd.ambient_depth = 0;
	//prd.seed = rnd_seeds[launch_index];
#ifdef CONTRIB
	prd.rcoef = make_contrib3(1.0f);
#endif
#ifdef ANTIMATTER
	prd.mask = 0u;
	prd.inside = 0;
#endif
	setupPayload(prd);

	/* Zero the output */
	for (int i = 0; i < contrib_buffer.size().x; i++)
		contrib_buffer[make_uint3(i, launch_index.x, launch_index.y)] = make_contrib4(0.0f);

	float3 org = origin_buffer[index];
	float3 dir = direction_buffer[index];

	if (dot(dir, dir) > 0.0f) {
		const float tmin = ray_start(org, imm_irrad ? RAY_START : FTINY); // RAY_START is too large for rfluxmtx calls
		if (imm_irrad) {
			dir = -normalize(dir);
			Ray ray = make_Ray(org - dir * tmin, dir, RADIANCE_RAY, 0.0f, 2.0f * tmin);
			rtTrace(top_irrad, ray, prd);
		}
		else {
			Ray ray = make_Ray(org, normalize(dir), do_irrad ? PRIMARY_RAY : RADIANCE_RAY, tmin, lim_dist ? length(dir) : RAY_END);
			rtTrace(top_object, ray, prd);
		}
	}

	checkFinite(prd.result); // Probably not necessary

#ifdef RAY_COUNT
	ray_count_buffer[launch_index] = prd.ray_count;
#endif
}

RT_PROGRAM void exception()
{
#ifdef PRINT_OPTIX
	rtPrintExceptionDetails();
#endif
#ifdef CONTRIB_DOUBLE
	contrib_buffer[make_uint3(0, launch_index.x, launch_index.y)] = make_contrib4(rtGetExceptionCode(), 0.0f, 0.0f, -1.0f);
#else
	contrib_buffer[make_uint3(0, launch_index.x, launch_index.y)] = exceptionToFloat4(rtGetExceptionCode());
#endif
}