//
//  SharedUniforms.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 01.02.21.
//  Copyright © 2021 Eugene Lutz. All rights reserved.
//

#ifndef SharedUniforms_h
#define SharedUniforms_h

#include <simd/simd.h>

#include "render_target_index.h"

typedef struct VERTEX_UV
{
	simd_float2 position;
	simd_float2 uv;
}
VERTEX_UV;

typedef struct VERTEX_NUV
{
	simd_float3 position;
	simd_float3 normal;
	simd_float2 uv;
}
VERTEX_NUV;

typedef struct POINT_LIGHT
{
	simd_float3 location;
	//simd_float3 eye_space_location;
	simd_float3 color;
	float radius;
}
POINT_LIGHT;

typedef struct MODEL_UNIFORMS
{
	simd_float3x3 normal;
	simd_float4x4 model;
}
MODEL_UNIFORMS;

typedef struct VIEWPORT_UNIFORMS
{
	simd_float4x4 view;
	simd_float4x4 projection;
	simd_float4x4 viewProjection;
}
VIEWPORT_UNIFORMS;

typedef struct TEXTURED_VERTEX_UNIFORMS
{
	simd_float3x3 normal;
	
	simd_float4x4 model;
	simd_float4x4 view;
	simd_float4x4 projection;
	
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

#endif /* SharedUniforms_h */
