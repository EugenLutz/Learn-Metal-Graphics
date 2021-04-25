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

// MARK: - GBuffer pass

typedef struct GBufferFragmentIn
{
	float4 position [[position]];
	//float3 eye_position;
	float2 uv;
	float eye_z;
	half3 normal;
}
GBufferFragmentIn;

vertex GBufferFragmentIn dl_normal_v(uint vid [[ vertex_id ]],
									 constant VERTEX_NUV* vertexBuffer [[ buffer(0) ]],
									 constant MODEL_UNIFORMS& uniforms [[ buffer(1) ]],
									 constant VIEWPORT_UNIFORMS& viewportUniforms [[ buffer(2) ]])
{
	constant VERTEX_NUV& vert = vertexBuffer[vid];
	float4 eye_position = viewportUniforms.view * uniforms.model * float4(vert.position, 1.0f);
	float3 normal = uniforms.normal * vert.normal;
	//float4 normal4 = float4(normal, 1);
	//normal = (viewportUniforms.invertedView * normal4).xyz;
   
	GBufferFragmentIn out
	{
		.position = viewportUniforms.projection * eye_position,
		//.eye_position = eye_position.xyz,
		.uv = vert.uv,
		.eye_z = eye_position.z,
		.normal = half3(normal)
	};

	return out;
}

typedef struct NormalFunctionOut
{
	half4 albedo [[ color(RENDER_TARGET_INDEX_COMPOSE) ]];
	half4 normal [[ color(RENDER_TARGET_INDEX_NORMAL) ]];
	float depth [[ color(RENDER_TARGET_INDEX_DEPTH) ]];
}
NormalFunctionOut;

fragment NormalFunctionOut dl_normal_f(GBufferFragmentIn in [[ stage_in ]],
									   sampler textureSampler [[ sampler(0) ]],
									   texture2d<half> texture [[ texture(0) ]])
{
	NormalFunctionOut out;
	out.albedo = half4(texture.sample(textureSampler, in.uv));
	out.albedo.xyz *= 0.3f;
	out.normal = half4(normalize(in.normal), 1.0f);
	//out.depth = in.eye_position.z;
	out.depth = in.eye_z;
	return out;
}

// MARK: - Light mask

//

// MARK: - Light

typedef struct PointLightFragmentIn
{
	uint lightIndex [[ flat ]];
	float4 position [[ position ]];
	float3 fragmentPosition_eye;
	float4 lightLocation_eye;
}
PointLightFragmentIn;

vertex PointLightFragmentIn dl_pointLight_v(uint vid [[ vertex_id ]],
											uint iid [[ instance_id ]],
											constant float3* vertices [[ buffer(0) ]],
											constant POINT_LIGHT* pointLights [[ buffer(1) ]],
											constant VIEWPORT_UNIFORMS& viewportUniforms [[ buffer(2) ]])
{
	constant POINT_LIGHT& light = pointLights[iid];
	
	float4 eye_location = viewportUniforms.view * float4(light.location, 1.0f);
	//float3 fragmentPosition_eye = vertices[vid] * light.radius + light.location;
	//float4 location = viewportUniforms.view * float4(fragmentPosition_eye, 1.0f);
	//fragmentPosition_eye = location.xyz;
	
	float3 fragmentPosition_eye = vertices[vid] * light.radius + eye_location.xyz;
	float4 location = float4(fragmentPosition_eye, 1.0f);
	fragmentPosition_eye = location.xyz;
	
	PointLightFragmentIn out =
	{
		.position = viewportUniforms.projection * location,
		.fragmentPosition_eye = fragmentPosition_eye,
		.lightIndex = iid,
		.lightLocation_eye = eye_location
	};
	
	return out;
}

fragment half4 dl_pointLight_f(PointLightFragmentIn in [[ stage_in ]],
							   texture2d<half> normalMap [[ texture(0) ]],
							   texture2d<float> depthMap [[ texture(1) ]],
							   constant POINT_LIGHT* pointLights [[ buffer(1) ]])
{
	uint2 xy = uint2(in.position.xy);
	half4 normal = normalMap.read(xy);
	float depth = depthMap.read(xy).x;
	
	float3 eye_space_fragment_pos = in.fragmentPosition_eye * (depth / in.fragmentPosition_eye.z);
	float3 light_eye_position = in.lightLocation_eye.xyz;
	float light_distance = length(light_eye_position - eye_space_fragment_pos);
	float light_radius = pointLights[in.lightIndex].radius;
		
	if (light_distance < light_radius)
	{
		float intensity = 1.0f - (light_distance / light_radius);
		float3 light_direction = normalize(light_eye_position - eye_space_fragment_pos);
		intensity *= max(dot(float3(normal.xyz), light_direction), 0.0f);
		
		half3 color = half3(pointLights[in.lightIndex].color.xyz * intensity);
		return half4(color, 1);
	}
	
	return half4(0.0f, 0.0f, 0.0f, 0.0f);
}
