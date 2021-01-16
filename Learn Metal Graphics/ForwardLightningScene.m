//
//  ForwardLightningScene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 07.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "ForwardLightningScene.h"

@implementation ForwardLightningScene
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
	self.automaticRotationRate = (float)(M_PI / 5.0);
	
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
	_vertexUniforms.modelView = simd_mul(self.viewMatrix, matrix_identity_float4x4);
	_vertexUniforms.modelViewProjection = self.viewProjectionMatrix;
	
	_fragmentUniforms.pointLight[0].location = simd_make_float3(-0.8f, 1.0f, -1.0f);
	_fragmentUniforms.pointLight[0].color = simd_make_float3(0.8f, 0.7f, 0.05f);
	_fragmentUniforms.pointLight[0].color = simd_make_float3(1.0f, 0.8f, 0.05f);
	_fragmentUniforms.pointLight[0].radius = 10.0f;
	_fragmentUniforms.pointLight[1].location = simd_make_float3(0.0f, 2.5f, 0.0f);
	_fragmentUniforms.pointLight[1].color = simd_make_float3(0.1f, 1.0f, 0.1f);
	_fragmentUniforms.pointLight[1].radius = 10.0f;
	_fragmentUniforms.ambient = simd_make_float3(0.2f, 0.2f, 0.2f);
	_fragmentUniforms.ambient = simd_make_float3(0.1f, 0.1f, 0.1f);
	_fragmentUniforms.ambient = simd_make_float3(0.0f, 0.0f, 0.0f);
	
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
		
		[renderCommandEncoder setVertexBuffer:self.sceneRenderer.texturedCubeBuffer offset:0 atIndex:0];
		[renderCommandEncoder setVertexBytes:&_vertexUniforms length:sizeof(_vertexUniforms) atIndex:1];
		
		//[renderCommandEncoder setFragmentTexture:self.sceneRenderer.placeholderTexture atIndex:0];
		[renderCommandEncoder setFragmentTexture:self.sceneRenderer.rock1Texture atIndex:0];
		[renderCommandEncoder setFragmentSamplerState:self.sceneRenderer.defaultLinearMipMapMaxAnisotropicSampler atIndex:0];
		[renderCommandEncoder setFragmentBytes:&_fragmentUniforms length:sizeof(_fragmentUniforms) atIndex:0];
		
		[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numTexturedCubeBufferVertices];
	}
}

@end
