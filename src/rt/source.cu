/*
 * Copyright (c) 2013-2015 Nathaniel Jones
 * Massachusetts Institute of Technology
 */

#include <optix_world.h>
//#include "optix_shader_common.h"

using namespace optix;

struct Transform
{
	optix::Matrix<3,3> m;
};

/* Program variables */
rtDeclareVariable(int, data, , ); /* texture ID */
rtDeclareVariable(int, type, , ); /* type of data (true for float) */
rtDeclareVariable(float3, minimum, , ); /* texture minimum coordinates */
rtDeclareVariable(float3, maximum, , ); /* texture maximum coordinates */
rtDeclareVariable(Transform, transform, , ); /* transformation matrix */
rtDeclareVariable(float, multiplier, , ) = 1.0f; /* multiplier for light source intensity */

// Calculate source distribution with correction for flat sources.
RT_CALLABLE_PROGRAM float3 flatcorr( const float3 direction, const float3 normal )
{
	//rtPrintf("FlatCorr Recieved (%f, %f, %f) (%f, %f, %f)\n", direction.x, direction.y, direction.z, normal.x, normal.y, normal.z);

	const float3 dir = transform.m * direction;

	float phi = acosf( dir.z );
	float theta = atan2f( -dir.y, -dir.x );
	theta += 2.0f * M_PIf * ( theta < 0.0f );

	/* Normalize to [0, 1] within range */
	phi = ( 180.0f * M_1_PIf * phi - minimum.x ) / ( maximum.x - minimum.x );
	theta = ( 180.0f * M_1_PIf * theta - minimum.y ) / ( maximum.y - minimum.y );

	float rdot = dot( direction, normal );
	if ( type )
		return make_float3( multiplier * rtTex2D<float>( data, phi, theta ) / fabsf( rdot ) ); // this is flatcorr from source.cal
	return multiplier * make_float3( rtTex2D<float4>( data, phi, theta ) ) / fabsf( rdot );
}