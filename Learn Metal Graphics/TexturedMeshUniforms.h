//
//  TexturedMeshUniforms.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#ifndef TexturedMeshUniforms_h
#define TexturedMeshUniforms_h

#include <simd/simd.h>
#include "VertexNUV.h"
#include "PointLight.h"

typedef struct TEXTURED_VERTEX_UNIFORMS
{
	simd_float4x4 modelView;
	simd_float4x4 modelViewProjection;
}
TEXTURED_VERTEX_UNIFORMS;


#define NUM_LIGHTS_FS 2

typedef struct MESH_NUV_FRAGMENT_UNIFORMS
{
	POINT_LIGHT pointLight[NUM_LIGHTS_FS];
	simd_float3 ambient;
}
MESH_NUV_FRAGMENT_UNIFORMS;

#endif /* TexturedMeshUniforms_h */
