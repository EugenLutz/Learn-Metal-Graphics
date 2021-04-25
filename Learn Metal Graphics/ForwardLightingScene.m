//
//  ForwardLightingScene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 07.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "ForwardLightingScene.h"

@implementation ForwardLightingScene
{
	//
}

- (instancetype)initWithSceneRenderer:(SceneRenderer*)sceneRenderer
{
	self = [super initWithSceneRenderer:sceneRenderer];
	if (self)
	{
		[self _initCommon];
	}
	return self;
}

- (void)_initCommon
{
	_useInstanceIndex = YES;
	_useArgumentBuffer = NO;
}

- (void)setup
{
	//self.automaticCameraRotationRate = (float)(M_PI / 5.0);
	//self.automaticCameraRotationRate = (float)(M_PI / 45.0);
	
	// MARK: setup render pass descriptor
	MTLRenderPassDescriptor* renderPassDescriptor = self.sceneRenderer.renderPassDescriptor;
	renderPassDescriptor.colorAttachments[0].loadAction = MTLStoreActionDontCare;
	renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionDontCare;
	renderPassDescriptor.depthAttachment.clearDepth = 0.0f;
	renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionDontCare;
	renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
}

- (void)drawWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder timeElapsed:(double)timeElapsed
{
	//_vertexUniforms.modelView = simd_mul(self.viewMatrix, matrix_identity_float4x4);
	//_vertexUniforms.modelViewProjection = self.viewProjectionMatrix;
	
	simd_float4x4 model = self.defaultObjectModelMatrix;
	model = simd_inverse(model);
	_vertexUniforms.normal = simd_matrix(simd_make_float3(model.columns[0]), simd_make_float3(model.columns[1]), simd_make_float3(model.columns[2]));
	_vertexUniforms.model = self.defaultObjectModelMatrix;
	_vertexUniforms.view = self.viewMatrix;
	_vertexUniforms.projection = self.projectionMatrix;
	_vertexUniforms.modelView = matrix4fMul(self.viewMatrix, self.defaultObjectModelMatrix);
	_vertexUniforms.modelViewProjection = matrix4fMul(self.projectionMatrix, _vertexUniforms.modelView);
	
	_fragmentUniforms.pointLight[0].location = vector3fCreate(-0.8f, 1.0f, -1.0f);
	_fragmentUniforms.pointLight[0].color = vector3fCreate(0.8f, 0.7f, 0.05f);
	_fragmentUniforms.pointLight[0].color = vector3fCreate(1.0f, 0.8f, 0.05f);
	_fragmentUniforms.pointLight[0].radius = 10.0f;
	_fragmentUniforms.pointLight[1].location = vector3fCreate(0.0f, 2.5f, 0.0f);
	_fragmentUniforms.pointLight[1].color = vector3fCreate(0.1f, 1.0f, 0.1f);
	_fragmentUniforms.pointLight[1].radius = 10.0f;
	_fragmentUniforms.ambient = vector3fCreate(0.2f, 0.2f, 0.2f);
	_fragmentUniforms.ambient = vector3fCreate(0.1f, 0.1f, 0.1f);
	_fragmentUniforms.ambient = vector3fCreate(0.0f, 0.0f, 0.0f);
	
	if (_useArgumentBuffer)
	{
		//
	}
	else
	{
		[renderCommandEncoder setRenderPipelineState:self.sceneRenderer.defaultDrawTexturedMeshState];
		[renderCommandEncoder setDepthStencilState:self.sceneRenderer.defaultDepthStencilState];
		[renderCommandEncoder setCullMode:MTLCullModeBack];
		[renderCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
		
		[renderCommandEncoder setVertexBuffer:self.sceneRenderer.cubeNUVBuffer offset:0 atIndex:0];
		[renderCommandEncoder setVertexBytes:&_vertexUniforms length:sizeof(_vertexUniforms) atIndex:1];
		
		//[renderCommandEncoder setFragmentTexture:self.sceneRenderer.placeholderTexture atIndex:0];
		[renderCommandEncoder setFragmentTexture:self.sceneRenderer.rock1Texture atIndex:0];
		[renderCommandEncoder setFragmentSamplerState:self.sceneRenderer.defaultLinearMipMapMaxAnisotropicSampler atIndex:0];
		[renderCommandEncoder setFragmentBytes:&_fragmentUniforms length:sizeof(_fragmentUniforms) atIndex:0];
		
		[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numCubeNUVBufferVertices];
	}
}

@end
