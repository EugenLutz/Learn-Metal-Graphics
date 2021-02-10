//
//  TexturedMeshShaders.metal
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "SharedUniforms.h"

kernel void processCubeUniforms(uint id [[ thread_position_in_grid ]],
								constant float4x4* modelTransform [[ buffer(0) ]],
								constant float4x4& viewProjection [[ buffer(1) ]],
								device float4x4* modelUniforms [[ buffer(2) ]])
{
	modelUniforms[id] = viewProjection * modelTransform[id];
}


struct VertexArgumentBuffer
{
	constant VERTEX_NUV* vertexBuffer [[ id(0) ]];
	constant float4x4* ndcTransformMatrices [[ id(1) ]];
	constant uint* instanceTransformMap [[ id(2) ]];
};

struct VertexInOut
{
	float4 clipSpacePosition [[position]];
	float2 uv;
};

vertex VertexInOut defaultArgumentedTexturedCubeVertexShader(uint vid [[ vertex_id ]],
															 uint iid [[ instance_id ]],
															 constant VertexArgumentBuffer& arguments [[ buffer(0) ]])
{
	constant VERTEX_NUV& vb = arguments.vertexBuffer[vid];
	float4 position = float4(vb.position, 1.0f);
	
	VertexInOut out;
	out.clipSpacePosition = arguments.ndcTransformMatrices[iid] * position;
	out.uv = vb.uv;
	
	return out;
}


struct FragmentArgumentBuffer
{
	texture2d<half> texture [[ id(0) ]];
	sampler textureSampler [[ id(1) ]];
	float3 lightPosition [[ id(2) ]];
	float3 lightColor [[ id(3) ]];
};

fragment half4 defaultArgumentedTexturedCubeFragmentShader(VertexInOut in [[ stage_in ]],
														   constant FragmentArgumentBuffer& arguments [[ buffer(0) ]])
{
	half4 color = half4(arguments.texture.sample(arguments.textureSampler, in.uv));
	return color;
}
