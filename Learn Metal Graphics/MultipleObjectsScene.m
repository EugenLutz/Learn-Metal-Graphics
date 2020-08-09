//
//  MultipleObjectsScene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 07.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "MultipleObjectsScene.h"
#include "TexturedMeshUniforms.h"

@implementation MultipleObjectsScene
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
	TEXTURED_VERTEX_UNIFORMS uniforms;
	uniforms.modelViewProjection = self.viewProjectionMatrix;
	NSUInteger bufferSize = sizeof(TEXTURED_VERTEX_UNIFORMS);
	
	[renderCommandEncoder setRenderPipelineState:self.sceneRenderer.defaultDrawTexturedMeshState];
	[renderCommandEncoder setDepthStencilState:self.sceneRenderer.defaultDepthStencilState];
	[renderCommandEncoder setCullMode:MTLCullModeBack];
	[renderCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	[renderCommandEncoder setVertexBuffer:self.sceneRenderer.texturedCubeBuffer offset:0 atIndex:0];
	[renderCommandEncoder setVertexBytes:&uniforms length:bufferSize atIndex:1];
	[renderCommandEncoder setFragmentTexture:self.sceneRenderer.rock2Texture atIndex:0];
	[renderCommandEncoder setFragmentSamplerState:self.sceneRenderer.defaultLinearMipMapMaxAnisotropicSampler atIndex:0];
	[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numTexturedCubeBufferVertices];
}

@end
