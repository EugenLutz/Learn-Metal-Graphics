//
//  SceneRenderer.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "SceneRenderer.h"
#import "Scene.h"
#import "ForwardLightingScene.h"
#import "DeferredLightingScene.h"
#include "SharedUniforms.h"
#include <simd/simd.h>

@implementation SceneRenderer
{	
	id<MTLCommandQueue> _commandQueue;
	
	Scene* _currentScene;
	double _lastUpdateTime;
}

- (instancetype)initWithMetalKitView:(MTKView*)metalKitView
{
	self = [super init];
	if (self)
	{
		assert(metalKitView);
		_metalKitView = metalKitView;
		_device = metalKitView.device;
		_defaultLibrary = [metalKitView.device newDefaultLibrary];
		_lastUpdateTime = (double)CACurrentMediaTime();
		[self _initCommon];
	}
	return self;
}

- (MTLRenderPipelineDescriptor*)_createDefaultRenderPipelineDescriptor
{
	MTLRenderPipelineDescriptor* renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	renderPipelineDescriptor.rasterSampleCount = _defaultRasterSampleCount;
	renderPipelineDescriptor.colorAttachments[0].pixelFormat = _defaultColorPixelFormat;

	// RGB =   (Source.rgb * <sourceRGBBlendFactor>)  <rgbBlendOperation>  (Dest.rgb * <destinationRGBBlendFactor>)
	// Alpha = (Source.a * <sourceAlphaBlendFactor>) <alphaBlendOperation> (Dest.a * <destinationAlphaBlendFactor>)
	 
	renderPipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
	
	renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
	renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
	renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	
	renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
	renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
	renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	
	
	renderPipelineDescriptor.depthAttachmentPixelFormat = _defaultDepthStencilPixelFormat;
	renderPipelineDescriptor.stencilAttachmentPixelFormat = _defaultDepthStencilPixelFormat;
	
	return renderPipelineDescriptor;
}

- (void)_initCommon
{
	NSLog(@"Selected Device: %@", _device.name);
	
	MTLArgumentBuffersTier tier = _device.argumentBuffersSupport;
	switch (tier)
	{
		case MTLArgumentBuffersTier1: NSLog(@"Argument Buffers Tier 1 is supported."); break;
		case MTLArgumentBuffersTier2: NSLog(@"Argument Buffers Tier 2 is supported."); break;
		default: NSLog(@"Argument Buffers are not supported."); break;
	}
	
	BOOL supportsRaytracing = _device.supportsRaytracing;
	if (supportsRaytracing) {
		NSLog(@"Raytracing is supported.");
	} else {
		NSLog(@"Raytracing is not supported.");
	}
	
	NSUInteger maxSamplerCount = _device.maxArgumentBufferSamplerCount;
	NSLog(@"Max argument buffer sampler count: %ld", maxSamplerCount);

	_numDynamicBuffers = 3;
	_currentDynamicBuffer = 0;
	
	_accessSemaphore = dispatch_semaphore_create(1);
	_frameBoundarySemaphore = dispatch_semaphore_create(_numDynamicBuffers);
	
	_drawableSize = simd_make_float2(_metalKitView.drawableSize.width, _metalKitView.drawableSize.height);
	_currentDrawableInRenderLoop = nil;
	
	// MARK: command queue
	_commandQueue = [_device newCommandQueue];
	
	
	// MARK: setup view
	_metalKitView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
	_defaultDepthStencilPixelFormat = _metalKitView.depthStencilPixelFormat;
	
	// MARK: default depth/stencil state
	MTLDepthStencilDescriptor* dsDesc = [[MTLDepthStencilDescriptor alloc] init];
	dsDesc.label = @"Default depth/stencil state";
	dsDesc.depthWriteEnabled = YES;
	dsDesc.depthCompareFunction = MTLCompareFunctionLess;
	
	dsDesc.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionAlways;
	dsDesc.frontFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;	// ignored because "compare f. always"
	dsDesc.frontFaceStencil.depthFailureOperation = MTLStencilOperationKeep;	// ignored because "compare f. always"
	dsDesc.frontFaceStencil.depthStencilPassOperation = MTLStencilOperationIncrementClamp;
	dsDesc.frontFaceStencil.readMask = 0x00;	// ignored because "compare f. always"
	dsDesc.frontFaceStencil.writeMask = 0xFF;
	
	dsDesc.backFaceStencil = nil;
	
	_defaultDepthStencilState = [_device newDepthStencilStateWithDescriptor:dsDesc];
	assert(_defaultDepthStencilState);
	
	
	// MARK: setup default render pipeline state
	id<MTLLibrary> library = _defaultLibrary;
	
	id<MTLFunction> vertexFunction = [library newFunctionWithName:@"defaultTexturedCubeVertexShader"];
	assert(vertexFunction);
	
	id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"defaultTexturedCubeFragmentShader"];
	assert(fragmentFunction);
	
	_defaultRasterSampleCount = _metalKitView.sampleCount;
	_defaultColorPixelFormat = _metalKitView.colorPixelFormat;
	
	MTLRenderPipelineDescriptor* renderPipelineDescriptor = [self _createDefaultRenderPipelineDescriptor];
	renderPipelineDescriptor.label = @"Textured mesh renderer";
	renderPipelineDescriptor.vertexFunction = vertexFunction;
	renderPipelineDescriptor.fragmentFunction = fragmentFunction;
	NSError* error = nil;
	_defaultDrawTexturedMeshState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
	assert(_defaultDrawTexturedMeshState);
	
	
	// MARK: setup default render pipeline state with argument buffer
	vertexFunction = [library newFunctionWithName:@"defaultArgumentedTexturedCubeVertexShader"];
	assert(vertexFunction);
	
	fragmentFunction = [library newFunctionWithName:@"defaultArgumentedTexturedCubeFragmentShader"];
	assert(fragmentFunction);
	
	renderPipelineDescriptor = [self _createDefaultRenderPipelineDescriptor];
	renderPipelineDescriptor.label = @"Textured mesh renderer with argument buffer";
	renderPipelineDescriptor.vertexFunction = vertexFunction;
	renderPipelineDescriptor.fragmentFunction = fragmentFunction;
	_defaultDrawArgumentedTexturedMeshState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
	assert(_defaultDrawArgumentedTexturedMeshState);
	
	
	// MARK: setup sampler state
	MTLSamplerDescriptor* samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
	samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
	samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
	samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
	samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
	samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
	samplerDescriptor.rAddressMode = MTLSamplerAddressModeRepeat;
	samplerDescriptor.compareFunction = MTLCompareFunctionLess;
	samplerDescriptor.maxAnisotropy = 16;
	_defaultLinearMipMapMaxAnisotropicSampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
	assert(_defaultLinearMipMapMaxAnisotropicSampler);
	
	
	// MARK: textures
	NSBundle* mainBundle = NSBundle.mainBundle;
	NSURL* textureURL = [mainBundle URLForResource:@"rock1" withExtension:@"png"];
	NSMutableDictionary<MTKTextureLoaderOption, id>* loadOptions = [[NSMutableDictionary alloc] init];
	[loadOptions setValue:@NO forKey:MTKTextureLoaderOptionSRGB];
	[loadOptions setValue:@YES forKey:MTKTextureLoaderOptionGenerateMipmaps];
	
	// rock1.png
	MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:_device];
	_rock1Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_rock1Texture);
	
	// rock2.png
	textureURL = [mainBundle URLForResource:@"rock2" withExtension:@"png"];
	_rock2Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_rock2Texture);
	
	// grass1.png
	textureURL = [mainBundle URLForResource:@"grass1" withExtension:@"png"];
	_grass1Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_grass1Texture);
	
	// grass2.png
	textureURL = [mainBundle URLForResource:@"grass2" withExtension:@"png"];
	_grass2Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_grass2Texture);
	
	// wood1.png
	textureURL = [mainBundle URLForResource:@"wood1" withExtension:@"png"];
	_wood1Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_wood1Texture);
	
	// wood2.png
	textureURL = [mainBundle URLForResource:@"wood2" withExtension:@"png"];
	_wood2Texture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_wood2Texture);
	
	// placeholder.png
	textureURL = [mainBundle URLForResource:@"placeholder" withExtension:@"png"];
	_placeholderTexture = [loader newTextureWithContentsOfURL:textureURL options:loadOptions error:&error];
	assert(_placeholderTexture);
	
	
	// MARK: create upload vertex buffers encoder
	id<MTLCommandBuffer> uploadCommandBuffer = [self createNewCommandBuffer];
	id<MTLBlitCommandEncoder> uploadDataCommandEncoder = [uploadCommandBuffer blitCommandEncoder];
	
	
	// MARK: create texturedFullScreenQuadBuffer
	
	const VERTEX_UV cubeVertices[] = {
		// Bottom right
		{ { -1.0f, -1.0f }, { 0.0f, 1.0f } },
		{ { 1.0f, -1.0f }, { 1.0f, 1.0f } },
		{ { 1.0f, 1.0f }, { 1.0f, 0.0f } },
		
		// Top left
		{ { 1.0f, 1.0f }, { 1.0f, 0.0f } },
		{ { -1.0f, 1.0f }, { 0.0f, 0.0f } },
		{ { -1.0f, -1.0f }, { 0.0f, 1.0f } }
	};
	
	NSUInteger copyBufferLength = sizeof(cubeVertices);
	id<MTLBuffer> copyBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceCPUCacheModeDefaultCache];
	assert(copyBuffer);
	memcpy(copyBuffer.contents, cubeVertices, copyBufferLength);
	
	_texturedFullScreenQuadBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceStorageModePrivate];
	assert(_texturedFullScreenQuadBuffer);
	
	_numTexturedFullScreenQuad = copyBufferLength / sizeof(VERTEX_UV);
	
	[uploadDataCommandEncoder copyFromBuffer:copyBuffer sourceOffset:0 toBuffer:_texturedFullScreenQuadBuffer destinationOffset:0 size:copyBufferLength];
	
	
	// MARK: create vertex buffers and schedule for uploading
	// Create textured cube vertex buffer
	const float val = 0.5f;
	const simd_float3 cv[] = {
		{ -val, -val,  val }, {  val, -val,  val }, {  val,  val,  val }, { -val,  val,  val },	// Front
		{  val, -val, -val }, { -val, -val, -val }, { -val,  val, -val }, {  val,  val, -val }	// Back
	};
	const simd_float3 cn[] = {
		simd_normalize(cv[0]), simd_normalize(cv[1]), simd_normalize(cv[2]), simd_normalize(cv[3]),	// Front
		simd_normalize(cv[4]), simd_normalize(cv[5]), simd_normalize(cv[6]), simd_normalize(cv[7])	// Back
	};
	const simd_float2 uv[] = { { 0.0f, 1.0f }, { 1.0f, 1.0f }, { 1.0f, 0.0f }, { 0.0f, 0.0f } };
	//const simd_float2 uv[] = { { 0.0f, 8.0f }, { 8.0f, 8.0f }, { 8.0f, 0.0f }, { 0.0f, 0.0f } };
	const VERTEX_NUV texturedCubeVertices[] = {	// Counterclockwise triangles
		{cv[3],cn[3],uv[3]}, {cv[0],cn[0],uv[0]}, {cv[1],cn[1],uv[1]},
		{cv[1],cn[1],uv[1]}, {cv[2],cn[2],uv[2]}, {cv[3],cn[3],uv[3]},	// Front
		
		{cv[2],cn[2],uv[3]}, {cv[1],cn[1],uv[0]}, {cv[4],cn[4],uv[1]},
		{cv[4],cn[4],uv[1]}, {cv[7],cn[7],uv[2]}, {cv[2],cn[2],uv[3]},	// Right
		
		{cv[7],cn[7],uv[3]}, {cv[4],cn[4],uv[0]}, {cv[5],cn[5],uv[1]},
		{cv[5],cn[5],uv[1]}, {cv[6],cn[6],uv[2]}, {cv[7],cn[7],uv[3]},	// Back
		
		{cv[6],cn[6],uv[3]}, {cv[5],cn[5],uv[0]}, {cv[0],cn[0],uv[1]},
		{cv[0],cn[0],uv[1]}, {cv[3],cn[3],uv[2]}, {cv[6],cn[6],uv[3]},	// Left
		
		{cv[6],cn[6],uv[3]}, {cv[3],cn[3],uv[0]}, {cv[2],cn[2],uv[1]},
		{cv[2],cn[2],uv[1]}, {cv[7],cn[7],uv[2]}, {cv[6],cn[6],uv[3]},	// Top
		
		{cv[0],cn[0],uv[3]}, {cv[5],cn[5],uv[0]}, {cv[4],cn[4],uv[1]},
		{cv[4],cn[4],uv[1]}, {cv[1],cn[1],uv[2]}, {cv[0],cn[0],uv[3]}	// Bottom
	};
	
	copyBufferLength = sizeof(texturedCubeVertices);
	copyBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceCPUCacheModeDefaultCache];
	assert(copyBuffer);
	memcpy(copyBuffer.contents, texturedCubeVertices, copyBufferLength);
	
	_texturedCubeBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceStorageModePrivate];
	assert(_texturedCubeBuffer);
	
	_numTexturedCubeBufferVertices = copyBufferLength / sizeof(VERTEX_NUV);
	
	[uploadDataCommandEncoder copyFromBuffer:copyBuffer sourceOffset:0 toBuffer:_texturedCubeBuffer destinationOffset:0 size:copyBufferLength];
	
	
	// MARK: schedule uploading vertex buffers
	[uploadDataCommandEncoder endEncoding];
	[self scheduleCommandBuffer:uploadCommandBuffer];
	
	
	// MARK: wait for all vertex buffers uploaded
	[uploadCommandBuffer waitUntilCompleted];
		
	// MARK: scenes
#define SCENE_ID 1
#if SCENE_ID == 0
	_currentScene = [[ForwardLightingScene alloc] initWithSceneRenderer:self];
#elif SCENE_ID == 1
	_currentScene = [[DeferredLightingScene alloc] initWithSceneRenderer:self];
#endif
	[_currentScene setup];
}

- (void)_lock
{
	dispatch_semaphore_wait(_accessSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)_unlock
{
	dispatch_semaphore_signal(_accessSemaphore);
}

- (MTLRenderPassDescriptor*)renderPassDescriptor
{
	return _metalKitView.currentRenderPassDescriptor;
}


- (id<MTLCommandBuffer>)beginFrameWithNewCommandBufferAndOccupyRenderer
{
	// Occupy renderer by increasing access semaphore
	dispatch_semaphore_wait(_frameBoundarySemaphore, DISPATCH_TIME_FOREVER);
	
	// Increase index of dynamic buffer
	_currentDynamicBuffer = (_currentDynamicBuffer + 1) % _numDynamicBuffers;
	
	// Create render command buffer
	id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
	return commandBuffer;
}

- (id<MTLCommandBuffer>)createNewCommandBuffer
{
	// Create render command buffer
	id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
	return commandBuffer;
}

- (void)scheduleReleaseRendererAfterCommandBufferCompletion:(id<MTLCommandBuffer>)commandBuffer
{
	__block dispatch_semaphore_t blockFrameBoundarySemaphore = _frameBoundarySemaphore;
	[commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cmdBuf) {
		dispatch_semaphore_signal(blockFrameBoundarySemaphore);
	}];
}

- (void)scheduleCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
	// Send render commands for execution execute to gpu
	[commandBuffer commit];
}

- (void)endFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
	// There is no sence to draw anything if drawable is unavailable...
	// But for now, schedule command to present drawable if it exists.
	id<CAMetalDrawable> drawable = _currentDrawableInRenderLoop;
	if (drawable) {
		[commandBuffer presentDrawable:drawable];
	}
	
	// Send render commands for execution execute to gpu
	[commandBuffer commit];
}



- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
	[self _lock];
	
	_drawableSize = simd_make_float2(size.width, size.height);
	[_currentScene drawableResized:_drawableSize];
	
	[self _unlock];
}

- (void)drawInMTKView:(MTKView*)view
{
	[self _lock];
	
	double currentTime = CACurrentMediaTime();
	double timeElapsed = currentTime - _lastUpdateTime;
	_lastUpdateTime = currentTime;
	
	_currentDrawableInRenderLoop = _metalKitView.currentDrawable;
	
	[_currentScene drawWithCommandQueue:_commandQueue timeElapsed:timeElapsed];
	
	_currentDrawableInRenderLoop = nil;
	
	[self _unlock];
	
	/*
	// Get current render pass descriptor
	MTLRenderPassDescriptor* currentRenderPassDescriptor = view.currentRenderPassDescriptor;
	if (!currentRenderPassDescriptor) {
		return;
	}
	
	// Occupy renderer by increasing access semaphore
	dispatch_semaphore_wait(_frameBoundarySemaphore, DISPATCH_TIME_FOREVER);
	
	// Increase index of dynamic buffer
	_currentDynamicBuffer = (_currentDynamicBuffer + 1) % _numDynamicBuffers;
	
	// Create render command buffer
	id<MTLCommandBuffer> renderCommandBuffer = [_commandQueue commandBuffer];
	__block dispatch_semaphore_t blockFrameBoundarySemaphore = _frameBoundarySemaphore;
	[renderCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cmdBuf) {
		dispatch_semaphore_signal(blockFrameBoundarySemaphore);
	}];
	
	// Create and draw to render command encoder
	id<MTLRenderCommandEncoder> encoder = [renderCommandBuffer renderCommandEncoderWithDescriptor:currentRenderPassDescriptor];
	[_currentScene drawWithRenderCommandEncoder:encoder];
	[encoder endEncoding];
	
	// There is no sence to draw anything if drawable is unavailable...
	// But for now, schedule command to present drawable if it exists.
	id<CAMetalDrawable> drawable = view.currentDrawable;
	if (drawable) {
		[renderCommandBuffer presentDrawable:drawable];
	}
	
	// Send render commands for execution execute to gpu
	[renderCommandBuffer commit];
	//*/
}

@end
