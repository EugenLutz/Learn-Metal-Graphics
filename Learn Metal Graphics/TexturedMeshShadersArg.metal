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





kernel void
processCubeUniforms_cs(uint id [[ thread_position_in_grid ]],
                       constant float4x4* modelTransform [[ buffer(0) ]],      // Every item of this array...
                       constant float4x4& viewProjection [[ buffer(1) ]],      // will be multiplied by this value...
                       device float4x4* ndcTransformMatrices [[ buffer(2) ]]   // and stored in this array.
                       ) {
    ndcTransformMatrices[id] = viewProjection * modelTransform[id];
    //ndcTransformMatrices[id] = modelTransform[id] * viewProjection;
}





struct VertexArgumentBuffer {
    uint instanceId [[ id(0) ]];
	constant VERTEX_NUV* vertexBuffer [[ id(1) ]];
	constant float4x4* ndcTransformMatrices [[ id(2) ]];
	
    // what???
    //constant uint* instanceTransformMap [[ id(3) ]];
};

struct VertexInOut {
	float4 clipSpacePosition [[position]];
	float2 uv;
};

vertex VertexInOut
texturedCube_arg_vs(uint vid [[ vertex_id ]],
                    constant VertexArgumentBuffer& arguments [[ buffer(0) ]]) {
	constant VERTEX_NUV& vb = arguments.vertexBuffer[vid];
	float4 position = float4(vb.position, 1.0f);
	
	VertexInOut out;
	out.clipSpacePosition = arguments.ndcTransformMatrices[arguments.instanceId] * position;
	out.uv = vb.uv;
	
	return out;
}





struct FragmentArgumentBuffer {
	texture2d<half> texture [[ id(0) ]];
	sampler textureSampler [[ id(1) ]];
	float3 lightPosition [[ id(2) ]];
	float3 lightColor [[ id(3) ]];
};

fragment half4
texturedCube_arg_fs(VertexInOut in [[ stage_in ]],
                    constant FragmentArgumentBuffer& arguments [[ buffer(0) ]]) {
	half4 color = half4(arguments.texture.sample(arguments.textureSampler, in.uv));
	return color;
}
