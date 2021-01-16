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
	float3 location;
	float3 normal;
	float2 uv;
};

vertex VertexInOut
defaultTexturedCubeVertexShader(uint vid [[ vertex_id ]],
								constant VERTEX_NUV* vertexBuffer [[ buffer(0) ]],
								constant TEXTURED_VERTEX_UNIFORMS& uniforms [[ buffer(1) ]])
{
	constant VERTEX_NUV& vb = vertexBuffer[vid];
	float4 positoin = float4(vb.position, 1.0f);
	
	VertexInOut out;
	out.clipSpacePosition = uniforms.modelViewProjection * positoin;
	out.location = vb.position;
	//out.normal = (uniforms.modelView * float4(vb.normal, 1.0f)).xyz;
	out.normal = vb.normal;
	out.uv = vb.uv;
	
	return out;
}

fragment half4
defaultTexturedCubeFragmentShader(VertexInOut in [[ stage_in ]],
								  texture2d<half> texture [[ texture(0) ]],
								  sampler textureSampler [[ sampler(0) ]],
								  constant MESH_NUV_FRAGMENT_UNIFORMS& uniforms [[ buffer(0) ]])
{
	half4 color = half4(texture.sample(textureSampler, in.uv));
	
	half4 result = half4(0, 0, 0, 1);
	//float resultCoefficient = 1.0f / (float)NUM_LIGHTS_FS;
	
	for (unsigned int i = 0; i < NUM_LIGHTS_FS; i++)
	{
		constant POINT_LIGHT& pointLight = uniforms.pointLight[i];
		
		float3 lightVector = in.location - pointLight.location;
		float lightIntencity = length(lightVector);
		lightIntencity = lightIntencity / pointLight.radius;
		lightIntencity = 1.0f - min(lightIntencity, 1.0f);
		
		float3 lightDirection = normalize(lightVector);
		float diffuseFactor = max(0.0f, -dot(in.normal, lightDirection));
		float3 diffuseColor = pointLight.color * diffuseFactor * lightIntencity;
		
		result.rgb += color.rgb * half3(uniforms.ambient + diffuseColor);// * resultCoefficient;
	}
	
	return result;
	
	/*constant POINT_LIGHT& pointLight = uniforms.pointLight;
	
	float3 lightVector = in.location - pointLight.location;
	float lightIntencity = length(lightVector);
	lightIntencity = lightIntencity / pointLight.radius;
	lightIntencity = 1.0f - min(lightIntencity, 1.0f);
	
	float3 lightDirection = normalize(lightVector);
	float diffuseFactor = max(0.0f, -dot(in.normal, lightDirection));
	float3 diffuseColor = pointLight.color * diffuseFactor * lightIntencity;
	
	half4 color = half4(texture.sample(textureSampler, in.uv));
	color.rgb = color.rgb * half3(uniforms.ambient + diffuseColor);
	
	return color;*/
}
