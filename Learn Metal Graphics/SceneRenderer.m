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
#define CUBE_SMOOTH_CORNERS 1
	// Create textured cube vertex buffer
	const float val = 0.5f;
	const simd_float3 cv[] = {
		{ -val, -val,  val }, {  val, -val,  val }, {  val,  val,  val }, { -val,  val,  val },	// Front
		{  val, -val, -val }, { -val, -val, -val }, { -val,  val, -val }, {  val,  val, -val }	// Back
	};
#if CUBE_SMOOTH_CORNERS
	const simd_float3 cn[] = {
		simd_normalize(cv[0]), simd_normalize(cv[1]), simd_normalize(cv[2]), simd_normalize(cv[3]),	// Front
		simd_normalize(cv[4]), simd_normalize(cv[5]), simd_normalize(cv[6]), simd_normalize(cv[7])	// Back
	};
#endif
	const simd_float2 uv[] = { { 0.0f, 1.0f }, { 1.0f, 1.0f }, { 1.0f, 0.0f }, { 0.0f, 0.0f } };
#if CUBE_SMOOTH_CORNERS
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
#else
	const simd_float3 cn[] = {
		{ 0.0f, 1.0f, 0.0f }, { 0.0f, -1.0f, 0.0f },	// top-bottom
		{ 0.0f, 0.0f, 1.0f }, { 0.0f, 0.0f, -1.0f },	// front-back
		{ -1.0f, 0.0f, 0.0f }, { 1.0f, 0.0f, 0.0f }		// left-right
	};
	const VERTEX_NUV texturedCubeVertices[] = {	// Counterclockwise triangles
		{cv[3],cn[2],uv[3]}, {cv[0],cn[2],uv[0]}, {cv[1],cn[2],uv[1]},
		{cv[1],cn[2],uv[1]}, {cv[2],cn[2],uv[2]}, {cv[3],cn[2],uv[3]},	// Front
		
		{cv[2],cn[5],uv[3]}, {cv[1],cn[5],uv[0]}, {cv[4],cn[5],uv[1]},
		{cv[4],cn[5],uv[1]}, {cv[7],cn[5],uv[2]}, {cv[2],cn[5],uv[3]},	// Right
		
		{cv[7],cn[3],uv[3]}, {cv[4],cn[3],uv[0]}, {cv[5],cn[3],uv[1]},
		{cv[5],cn[3],uv[1]}, {cv[6],cn[3],uv[2]}, {cv[7],cn[3],uv[3]},	// Back
		
		{cv[6],cn[4],uv[3]}, {cv[5],cn[4],uv[0]}, {cv[0],cn[4],uv[1]},
		{cv[0],cn[4],uv[1]}, {cv[3],cn[4],uv[2]}, {cv[6],cn[4],uv[3]},	// Left
		
		{cv[6],cn[0],uv[3]}, {cv[3],cn[0],uv[0]}, {cv[2],cn[0],uv[1]},
		{cv[2],cn[0],uv[1]}, {cv[7],cn[0],uv[2]}, {cv[6],cn[0],uv[3]},	// Top
		
		{cv[0],cn[1],uv[3]}, {cv[5],cn[1],uv[0]}, {cv[4],cn[1],uv[1]},
		{cv[4],cn[1],uv[1]}, {cv[1],cn[1],uv[2]}, {cv[0],cn[1],uv[3]}	// Bottom
	};
#endif
	
	copyBufferLength = sizeof(texturedCubeVertices);
	copyBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceCPUCacheModeDefaultCache];
	assert(copyBuffer);
	memcpy(copyBuffer.contents, texturedCubeVertices, copyBufferLength);
	
	_cubeNUVBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceStorageModePrivate];
	assert(_cubeNUVBuffer);
	
	_numCubeNUVBufferVertices = copyBufferLength / sizeof(VERTEX_NUV);
	
	[uploadDataCommandEncoder copyFromBuffer:copyBuffer sourceOffset:0 toBuffer:_cubeNUVBuffer destinationOffset:0 size:copyBufferLength];
	
	// MARK: Icosahedron
	
	simd_float3 icosahedronMeshVertices[] =
	{
		texturedCubeVertices[0].position, texturedCubeVertices[1].position, texturedCubeVertices[2].position,
		texturedCubeVertices[3].position, texturedCubeVertices[4].position, texturedCubeVertices[5].position,
		
		texturedCubeVertices[6].position, texturedCubeVertices[7].position, texturedCubeVertices[8].position,
		texturedCubeVertices[9].position, texturedCubeVertices[10].position, texturedCubeVertices[11].position,
		
		texturedCubeVertices[12].position, texturedCubeVertices[13].position, texturedCubeVertices[14].position,
		texturedCubeVertices[15].position, texturedCubeVertices[16].position, texturedCubeVertices[17].position,
		
		texturedCubeVertices[18].position, texturedCubeVertices[19].position, texturedCubeVertices[20].position,
		texturedCubeVertices[21].position, texturedCubeVertices[22].position, texturedCubeVertices[23].position,
		
		texturedCubeVertices[24].position, texturedCubeVertices[25].position, texturedCubeVertices[26].position,
		texturedCubeVertices[27].position, texturedCubeVertices[28].position, texturedCubeVertices[29].position,
		
		texturedCubeVertices[30].position, texturedCubeVertices[31].position, texturedCubeVertices[32].position,
		texturedCubeVertices[33].position, texturedCubeVertices[34].position, texturedCubeVertices[35].position
	};
	{
		unsigned int numItems = sizeof(icosahedronMeshVertices) / sizeof(simd_float3);
		for (unsigned int i = 0; i < numItems; i++)
		{
			simd_float3 value = icosahedronMeshVertices[i];
			
			if (value.x < 0) { value.x = -1.0f; }
			if (value.x > 0) { value.x = 1.0f; }
			
			if (value.y < 0) { value.y = -1.0f; }
			if (value.y > 0) { value.y = 1.0f; }
			
			if (value.z < 0) { value.z = -1.0f; }
			if (value.z > 0) { value.z = 1.0f; }
			
			icosahedronMeshVertices[i] = value;
		}
	}
	
	copyBufferLength = sizeof(icosahedronMeshVertices);
	copyBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceCPUCacheModeDefaultCache];
	assert(copyBuffer);
	memcpy(copyBuffer.contents, icosahedronMeshVertices, copyBufferLength);
	
	_icosahedronMeshBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceStorageModePrivate];
	assert(_icosahedronMeshBuffer);
	
	_numIcosahedronMeshBufferVertices = copyBufferLength / sizeof(simd_float3);
	
	[uploadDataCommandEncoder copyFromBuffer:copyBuffer sourceOffset:0 toBuffer:_icosahedronMeshBuffer destinationOffset:0 size:copyBufferLength];
	
	// MARK: Point lights
	
	const POINT_LIGHT pointLights[] =
	{
		{ { -0.56f, 0.56f, -0.56f }, { 0.4f, 0.4f, 0.0f }, 0.4f },
		{ { 0.56f, 0.56f, -0.56f }, { 0.4f, 0.0f, 0.2f }, 0.8f },
		{ { -0.51f, 0.51f, 0.51f }, { 0.6f, 0.2f, 0.2f }, 0.2f },
		{ { 0.0f, 0.6f, 0.0f }, { 0.6f, 0.2f, 0.6f }, 0.3f },
		{ { -0.51f, 0.2f, 0.51f }, { 0.6f, 0.2f, 0.2f }, 0.4f },
		{ { 0.56f, 0.1f, 0.56f }, { 0.4f, 0.4f, 0.0f }, 0.6f }
	};
	
	copyBufferLength = sizeof(pointLights);
	copyBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceCPUCacheModeDefaultCache];
	assert(copyBuffer);
	memcpy(copyBuffer.contents, pointLights, copyBufferLength);
	
	_pointLightsBuffer = [_device newBufferWithLength:copyBufferLength options:MTLResourceStorageModePrivate];
	assert(_pointLightsBuffer);
	
	_numPointLights = copyBufferLength / sizeof(POINT_LIGHT);
	
	[uploadDataCommandEncoder copyFromBuffer:copyBuffer sourceOffset:0 toBuffer:_pointLightsBuffer destinationOffset:0 size:copyBufferLength];
	
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
}

@end
