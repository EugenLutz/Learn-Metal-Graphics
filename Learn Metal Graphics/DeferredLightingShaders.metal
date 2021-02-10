//
//  DeferredLightingShaders.metal
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 17.01.21.
//  Copyright © 2021 Eugene Lutz. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "SharedUniforms.h"


// MARK: - Normals

typedef struct NormalIn
{
	float4 position [[position]];
	float3 normal;
}
NormalIn;

vertex NormalIn dl_normal_v(uint vid [[ vertex_id ]],
							 constant VERTEX_NUV* vertexBuffer [[ buffer(0) ]],
							 constant MODEL_UNIFORMS& uniforms [[ buffer(1) ]],
							 constant VIEWPORT_UNIFORMS& viewportUniforms [[ buffer(2) ]])
{
	float4 position = viewportUniforms.viewProjection * uniforms.model * float4(vertexBuffer[vid].position, 1.0f);
	float3 normal = uniforms.normal * vertexBuffer[vid].normal;
   
	NormalIn out
	{
		.position = position,
		.normal = normal
	};

	return out;
}

typedef struct NormalFunctionOut
{
	float4 color [[ color(RENDER_TARGET_INDEX_NORMAL) ]];
}
NormalFunctionOut;

fragment NormalFunctionOut dl_normal_f(NormalIn in [[ stage_in ]])
{
	NormalFunctionOut out;
	out.color = float4(float3(in.normal), 1.0);
	return out;
}


// MARK: - Compose

typedef struct ComposeFragmentIn
{
	float4 position [[ position ]];
	float2 uv;
}
ComposeFragmentIn;

vertex ComposeFragmentIn dl_compose_v(uint vid [[ vertex_id ]],
									  constant VERTEX_UV* vertexBuffer [[ buffer(0) ]])
{
	constant VERTEX_UV& v = vertexBuffer[vid];
	ComposeFragmentIn out =
	{
		.position = float4(v.position, 0.0f, 1.0f),
		.uv = v.uv
	};
	return out;
}

fragment half4 dl_compose_f(ComposeFragmentIn in [[ stage_in ]],
							texture2d<half> normalMap [[ texture(0) ]])
{
	uint2 xy = uint2(in.position.xy);
	return half4(normalMap.read(xy).xyz, 1.0f);
}
