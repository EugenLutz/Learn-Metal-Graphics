//
//  DeferredLightingScene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 16.01.21.
//  Copyright © 2021 Eugene Lutz. All rights reserved.
//

#import "DeferredLightingScene.h"

@implementation DeferredLightingScene
{
	MTLTextureDescriptor* _depthMapTextureDescriptor;
	id<MTLTexture> _depthMap;
	
	MTLTextureDescriptor* _normalMapTextureDescriptor;
	id<MTLTexture> _normalMap;
	
	MTLRenderPassDescriptor* _gBufferPassDescriptor;
	id<MTLDepthStencilState> _generateNormalMapDepthStencilState;
	id<MTLRenderPipelineState> _generateNormalMapPipelineState;
	
	MTLRenderPassDescriptor* _composeRenderPassDescriptor;
	id<MTLRenderPipelineState> _composePipelineState;
	
	MODEL_UNIFORMS _modelUniforms;
}

- (void)setup
{
	self.automaticallyRotateDefaultObject = YES;
	self.defaultObjectRotationRate = (float)(M_PI / 10.0);
	
	self.automaticallyRotateCamera = NO;
	self.automaticCameraRotationRate = (float)(M_PI / 10.0);
	
	id<MTLDevice> device = self.sceneRenderer.device;
	id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
	NSError* error = nil;
	
	_depthMapTextureDescriptor = [[MTLTextureDescriptor alloc] init];;
	_depthMapTextureDescriptor.pixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	_depthMapTextureDescriptor.width = (NSUInteger)self.sceneRenderer.drawableSize.x;
	_depthMapTextureDescriptor.height = (NSUInteger)self.sceneRenderer.drawableSize.y;
	_depthMapTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	_depthMapTextureDescriptor.storageMode = MTLStorageModePrivate;
	_depthMap = [device newTextureWithDescriptor:_depthMapTextureDescriptor];
	
	_normalMapTextureDescriptor = [[MTLTextureDescriptor alloc] init];;
	_normalMapTextureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
	_normalMapTextureDescriptor.width = (NSUInteger)self.sceneRenderer.drawableSize.x;
	_normalMapTextureDescriptor.height = (NSUInteger)self.sceneRenderer.drawableSize.y;
	_normalMapTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	_normalMapTextureDescriptor.storageMode = MTLStorageModePrivate;
	_normalMap = [device newTextureWithDescriptor:_normalMapTextureDescriptor];
	
	_gBufferPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].storeAction = MTLStoreActionDontCare;
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = nil;
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].loadAction = MTLLoadActionClear;
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].storeAction = MTLStoreActionStore;
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].texture = _normalMap;
	_gBufferPassDescriptor.depthAttachment.texture = _depthMap;
	_gBufferPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
	_gBufferPassDescriptor.depthAttachment.clearDepth = 1.0;
	//_gBufferPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
	_gBufferPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
	_gBufferPassDescriptor.stencilAttachment.texture = _depthMap;
	_gBufferPassDescriptor.stencilAttachment.loadAction = MTLLoadActionClear;
	_gBufferPassDescriptor.stencilAttachment.clearStencil = 0;
	//_gBufferPassDescriptor.stencilAttachment.storeAction = MTLStoreActionStore;
	_gBufferPassDescriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
	
	MTLStencilDescriptor* stencilStateDesc = nil;
	MTLDepthStencilDescriptor* depthStateDesc = [MTLDepthStencilDescriptor new];
	depthStateDesc.label = @"G-buffer Creation";
	depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
	depthStateDesc.depthWriteEnabled = YES;
	depthStateDesc.frontFaceStencil = stencilStateDesc;
	depthStateDesc.backFaceStencil = stencilStateDesc;
	_generateNormalMapDepthStencilState = [device newDepthStencilStateWithDescriptor:depthStateDesc];
	assert(_generateNormalMapDepthStencilState);
	
	MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineDescriptor.label = @"G-Buffer state";
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].pixelFormat = MTLPixelFormatInvalid;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].pixelFormat = _normalMapTextureDescriptor.pixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].blendingEnabled = YES;
	pipelineDescriptor.depthAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.stencilAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"dl_normal_v"];
	pipelineDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"dl_normal_f"];
	_generateNormalMapPipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
	if (error) {
		NSLog(@"%@", error.description);
	}
	assert(_generateNormalMapPipelineState);
	
	
	_composeRenderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
	_composeRenderPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].storeAction = MTLStoreActionDontCare;
	_composeRenderPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = nil;
	
	pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineDescriptor.label = @"Compose state";
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].pixelFormat = self.sceneRenderer.defaultColorPixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].blendingEnabled = NO;
	pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
	pipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
	pipelineDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"dl_compose_v"];
	pipelineDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"dl_compose_f"];
	_composePipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
	if (error) {
		NSLog(@"%@", error.description);
	}
	assert(_composePipelineState);
}

- (void)drawableResized:(simd_float2)size
{
	[super drawableResized:size];
	
	_depthMapTextureDescriptor.width = (NSUInteger)size.x;
	_depthMapTextureDescriptor.height = (NSUInteger)size.y;
	_depthMap = [self.sceneRenderer.device newTextureWithDescriptor:_depthMapTextureDescriptor];
	_gBufferPassDescriptor.depthAttachment.texture = _depthMap;
	_gBufferPassDescriptor.stencilAttachment.texture = _depthMap;
	
	_normalMapTextureDescriptor.width = (NSUInteger)size.x;
	_normalMapTextureDescriptor.height = (NSUInteger)size.y;
	_normalMap = [self.sceneRenderer.device newTextureWithDescriptor:_normalMapTextureDescriptor];
	_gBufferPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].texture = _normalMap;
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer timeElapsed:(double)timeElapsed
{
	_modelUniforms.model = self.defaultObjectModelMatrix;
	_modelUniforms.normal = matrix3fFromMatrix4f(self.defaultObjectModelMatrix);
	
	id<CAMetalDrawable> drawable = self.sceneRenderer.currentDrawableInRenderLoop;
	if (!drawable) {
		return;
	}
	
	{
		id<MTLRenderCommandEncoder> gBufferCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBufferPassDescriptor];
		
		[gBufferCommandEncoder setCullMode:MTLCullModeBack];
		[gBufferCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
		[gBufferCommandEncoder setStencilReferenceValue:128];
		[gBufferCommandEncoder setDepthStencilState:_generateNormalMapDepthStencilState];
		[gBufferCommandEncoder setRenderPipelineState:_generateNormalMapPipelineState];
		[gBufferCommandEncoder setVertexBuffer:self.sceneRenderer.texturedCubeBuffer offset:0 atIndex:0];
		[gBufferCommandEncoder setVertexBytes:&_modelUniforms length:sizeof(_modelUniforms) atIndex:1];
		[gBufferCommandEncoder setVertexBytes:self.viewportUniforms length:sizeof(*self.viewportUniforms) atIndex:2];
		[gBufferCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numTexturedCubeBufferVertices];
		
		[gBufferCommandEncoder endEncoding];
	}
	
	{
		_composeRenderPassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = drawable.texture;
		id<MTLRenderCommandEncoder> composeEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_composeRenderPassDescriptor];
		
		[composeEncoder setCullMode:MTLCullModeBack];
		[composeEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
		[composeEncoder setRenderPipelineState:_composePipelineState];
		[composeEncoder setVertexBuffer:self.sceneRenderer.texturedFullScreenQuadBuffer offset:0 atIndex:0];
		[composeEncoder setFragmentTexture:_normalMap atIndex:0];
		[composeEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numTexturedFullScreenQuad];
		
		[composeEncoder endEncoding];
	}
}

@end
