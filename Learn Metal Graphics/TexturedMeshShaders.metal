//
//  TexturedMeshShaders.metal
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "TexturedMeshUniforms.h"

struct VertexInOut
{
	float4 clipSpacePosition [[position]];
	//float3 vertexPosition;
	float2 uv;
};

vertex VertexInOut
defaultTexturedCubeVertexShader(uint vid [[ vertex_id ]],
								constant TEXTURED_VERTEX* vertexBuffer [[ buffer(0) ]],
								constant TEXTURED_VERTEX_UNIFORMS& uniforms [[ buffer(1) ]])
{
	constant TEXTURED_VERTEX& vb = vertexBuffer[vid];
	float4 positoin = float4(vb.position, 1.0f);
	
	VertexInOut out;
	out.clipSpacePosition = uniforms.modelViewProjection * positoin;
	out.uv = vb.uv;
	
	return out;
}

fragment half4
defaultTexturedCubeFragmentShader(VertexInOut in [[ stage_in ]],
								  texture2d<half> texture [[ texture(0) ]],
								  sampler textureSampler [[sampler(0)]])
{
	half4 color = half4(texture.sample(textureSampler, in.uv));
	return color;
}
