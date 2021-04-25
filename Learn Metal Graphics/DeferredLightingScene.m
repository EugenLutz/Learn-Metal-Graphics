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
	MTLTextureDescriptor* _normalMapTextureDescriptor;
	id<MTLTexture> _normalMap;
	
	MTLTextureDescriptor* _depthMapTextureDescriptor;
	id<MTLTexture> _depthMap;
	
	MTLRenderPassDescriptor* _singlePassDescriptor;
	
	id<MTLDepthStencilState> _gBufferDepthStencilState;
	id<MTLRenderPipelineState> _gBufferRenderPipelineState;
	
	id<MTLDepthStencilState> _pointLightDepthStencilState;
	id<MTLRenderPipelineState> _pointLightRenderPipelineState;
	
	MODEL_UNIFORMS _modelUniforms;
}

- (void)setup
{
	self.automaticallyRotateDefaultObject = YES;
	self.defaultObjectRotationRate = (float)(M_PI / 5.0);
	
	self.automaticallyRotateCamera = NO;
	self.automaticCameraRotationRate = (float)(M_PI / 5.0);
	self.cameraRotation = vector3fCreate(self.cameraRotation.x, 0.0f, self.cameraRotation.z);
	//self.cameraRotation = vector3fCreate(0.0f, 0.0f, self.cameraRotation.z);
	
	id<MTLDevice> device = self.sceneRenderer.device;
	id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
	NSError* error = nil;
	
	_normalMapTextureDescriptor = [[MTLTextureDescriptor alloc] init];
	_normalMapTextureDescriptor.pixelFormat = MTLPixelFormatRGBA8Snorm;
	_normalMapTextureDescriptor.width = (NSUInteger)self.sceneRenderer.drawableSize.x;
	_normalMapTextureDescriptor.height = (NSUInteger)self.sceneRenderer.drawableSize.y;
	_normalMapTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	_normalMapTextureDescriptor.storageMode = MTLStorageModePrivate;
	_normalMap = [device newTextureWithDescriptor:_normalMapTextureDescriptor];
	_normalMap.label = @"Normal Map";
	
	_depthMapTextureDescriptor = [[MTLTextureDescriptor alloc] init];
	_depthMapTextureDescriptor.pixelFormat = MTLPixelFormatR32Float;
	_depthMapTextureDescriptor.width = (NSUInteger)self.sceneRenderer.drawableSize.x;
	_depthMapTextureDescriptor.height = (NSUInteger)self.sceneRenderer.drawableSize.y;
	_depthMapTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	_depthMapTextureDescriptor.storageMode = MTLStorageModePrivate;
	_depthMap = [device newTextureWithDescriptor:_depthMapTextureDescriptor];
	_depthMap.label = @"Depth Map";
	
	_singlePassDescriptor = [[MTLRenderPassDescriptor alloc] init];
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].loadAction = MTLLoadActionClear;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].clearColor = MTLClearColorMake(0.0,0.0,0.0,1.0);
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].storeAction = MTLStoreActionStore;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = nil;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].loadAction = MTLLoadActionDontCare;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].storeAction = MTLStoreActionDontCare;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].texture = _normalMap;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].loadAction = MTLLoadActionDontCare;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].storeAction = MTLStoreActionDontCare;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].texture = _depthMap;
	_singlePassDescriptor.depthAttachment.texture = self.sceneRenderer.metalKitView.depthStencilTexture;
	_singlePassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
	_singlePassDescriptor.depthAttachment.clearDepth = 1.0;
	_singlePassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
	_singlePassDescriptor.stencilAttachment.texture = self.sceneRenderer.metalKitView.depthStencilTexture;
	_singlePassDescriptor.stencilAttachment.loadAction = MTLLoadActionClear;
	_singlePassDescriptor.stencilAttachment.clearStencil = 0;
	_singlePassDescriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
	
	MTLStencilDescriptor* stencilStateDesc = [[MTLStencilDescriptor alloc] init];
	stencilStateDesc.depthFailureOperation = MTLStencilOperationKeep;
	stencilStateDesc.stencilCompareFunction = MTLCompareFunctionAlways;
	stencilStateDesc.stencilFailureOperation = MTLStencilOperationKeep;
	stencilStateDesc.depthStencilPassOperation = MTLStencilOperationReplace;
	stencilStateDesc.readMask = 0xFF;
	stencilStateDesc.writeMask = 0xFF;
	MTLDepthStencilDescriptor* depthStateDesc = [MTLDepthStencilDescriptor new];
	depthStateDesc.label = @"G-buffer Creation";
	depthStateDesc.depthWriteEnabled = YES;
	depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
	depthStateDesc.frontFaceStencil = stencilStateDesc;
	depthStateDesc.backFaceStencil = nil;
	_gBufferDepthStencilState = [device newDepthStencilStateWithDescriptor:depthStateDesc];
	assert(_gBufferDepthStencilState);
	
	MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineDescriptor.label = @"G-Buffer state";
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].pixelFormat = self.sceneRenderer.defaultColorPixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].blendingEnabled = NO;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].pixelFormat = _normalMapTextureDescriptor.pixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].blendingEnabled = NO;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].pixelFormat = _depthMapTextureDescriptor.pixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].blendingEnabled = NO;
	pipelineDescriptor.depthAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.stencilAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"dl_normal_v"];
	pipelineDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"dl_normal_f"];
	_gBufferRenderPipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
	if (error) {
		NSLog(@"%@", error.description);
	}
	assert(_gBufferRenderPipelineState);
	
	// For drawing point lights
	stencilStateDesc = [[MTLStencilDescriptor alloc] init];
	stencilStateDesc.depthFailureOperation = MTLStencilOperationKeep;
	stencilStateDesc.stencilCompareFunction = MTLCompareFunctionEqual;
	stencilStateDesc.stencilFailureOperation = MTLStencilOperationKeep;
	stencilStateDesc.depthStencilPassOperation = MTLStencilOperationKeep;
	stencilStateDesc.readMask = 0b0001;
	stencilStateDesc.readMask = 0xFF;
	stencilStateDesc.writeMask = 0x0;
	depthStateDesc = [MTLDepthStencilDescriptor new];
	depthStateDesc.label = @"Point light depthStencil state";
	depthStateDesc.depthWriteEnabled = NO;
	depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
	depthStateDesc.frontFaceStencil = nil;
	depthStateDesc.backFaceStencil = stencilStateDesc;
	_pointLightDepthStencilState = [device newDepthStencilStateWithDescriptor:depthStateDesc];
	assert(_pointLightDepthStencilState);
	
	pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineDescriptor.label = @"Compose state";
	pipelineDescriptor.depthAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.stencilAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
	pipelineDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"dl_pointLight_v"];
	pipelineDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"dl_pointLight_f"];
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].pixelFormat = self.sceneRenderer.defaultColorPixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].blendingEnabled = YES;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].rgbBlendOperation = MTLBlendOperationAdd;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].alphaBlendOperation = MTLBlendOperationAdd;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].destinationRGBBlendFactor = MTLBlendFactorOne;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].destinationAlphaBlendFactor = MTLBlendFactorOne;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].sourceRGBBlendFactor = MTLBlendFactorOne;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].sourceAlphaBlendFactor = MTLBlendFactorOne;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].pixelFormat = _normalMapTextureDescriptor.pixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].blendingEnabled = NO;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].pixelFormat = _depthMapTextureDescriptor.pixelFormat;
	pipelineDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].blendingEnabled = NO;
	
	_pointLightRenderPipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
	if (error) {
		NSLog(@"%@", error.description);
	}
	assert(_pointLightRenderPipelineState);
}

- (void)drawableResized:(simd_float2)size
{
	[super drawableResized:size];
	
	_normalMapTextureDescriptor.width = (NSUInteger)size.x;
	_normalMapTextureDescriptor.height = (NSUInteger)size.y;
	_normalMap = [self.sceneRenderer.device newTextureWithDescriptor:_normalMapTextureDescriptor];
	_normalMap.label = @"Normal Map";
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_NORMAL].texture = _normalMap;
	
	_depthMapTextureDescriptor.width = (NSUInteger)size.x;
	_depthMapTextureDescriptor.height = (NSUInteger)size.y;
	_depthMap = [self.sceneRenderer.device newTextureWithDescriptor:_depthMapTextureDescriptor];
	_depthMap.label = @"Depth Map";
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_DEPTH].texture = _depthMap;
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer timeElapsed:(double)timeElapsed
{
	_modelUniforms.model = self.defaultObjectModelMatrix;
	
	matrix4f normal4 = matrix4fMul(self.viewMatrix, self.defaultObjectModelMatrix);
	_modelUniforms.normal = matrix3fFromMatrix4f(normal4);
	
	id<CAMetalDrawable> drawable = self.sceneRenderer.currentDrawableInRenderLoop;
	if (!drawable) {
		return;
	}
	
	[commandBuffer pushDebugGroup:@"Deferred lighting"];
	
	_singlePassDescriptor.depthAttachment.texture = self.sceneRenderer.metalKitView.depthStencilTexture;
	_singlePassDescriptor.stencilAttachment.texture = self.sceneRenderer.metalKitView.depthStencilTexture;
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = drawable.texture;
	id<MTLRenderCommandEncoder> deferredEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_singlePassDescriptor];
	
	[deferredEncoder setCullMode:MTLCullModeBack];
	[deferredEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	
	// Set stencil value to 1 where fragments are drawn
	[deferredEncoder setDepthStencilState:_gBufferDepthStencilState];
	[deferredEncoder setStencilReferenceValue:1];
	
	[deferredEncoder setRenderPipelineState:_gBufferRenderPipelineState];
	[deferredEncoder setVertexBuffer:self.sceneRenderer.cubeNUVBuffer offset:0 atIndex:0];
	[deferredEncoder setVertexBytes:&_modelUniforms length:sizeof(_modelUniforms) atIndex:1];
	[deferredEncoder setVertexBytes:self.viewportUniforms length:sizeof(*self.viewportUniforms) atIndex:2];
	[deferredEncoder setFragmentSamplerState:self.sceneRenderer.defaultLinearMipMapMaxAnisotropicSampler atIndex:0];
	[deferredEncoder setFragmentTexture:self.sceneRenderer.rock1Texture atIndex:0];
	[deferredEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numCubeNUVBufferVertices];
	
	
	// Drawing lights
	[deferredEncoder setCullMode:MTLCullModeFront];
	[deferredEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	
	// Execute fragment shader only on fragments, where stencil value equals to 1
	[deferredEncoder setDepthStencilState:_pointLightDepthStencilState];
	[deferredEncoder setStencilReferenceValue:1];
	
	[deferredEncoder setRenderPipelineState:_pointLightRenderPipelineState];
	[deferredEncoder setVertexBuffer:self.sceneRenderer.icosahedronMeshBuffer offset:0 atIndex:0];
	[deferredEncoder setVertexBuffer:self.sceneRenderer.pointLightsBuffer offset:0 atIndex:1];
	// Buffer already bound:
	//[deferredEncoder setVertexBytes:self.viewportUniforms length:sizeof(*self.viewportUniforms) atIndex:2];
	[deferredEncoder setFragmentTexture:_normalMap atIndex:0];
	[deferredEncoder setFragmentTexture:_depthMap atIndex:1];
	[deferredEncoder setFragmentBuffer:self.sceneRenderer.pointLightsBuffer offset:0 atIndex:1];
	[deferredEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numIcosahedronMeshBufferVertices instanceCount:self.sceneRenderer.numPointLights];
	
	[deferredEncoder endEncoding];
	
	[commandBuffer popDebugGroup];
	
	_singlePassDescriptor.colorAttachments[RENDER_TARGET_INDEX_COMPOSE].texture = nil;
}

@end
