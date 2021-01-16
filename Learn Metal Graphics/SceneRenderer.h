//
//  SceneRenderer.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

@import Metal;
@import MetalKit;
@import MetalPerformanceShaders;

NS_ASSUME_NONNULL_BEGIN

@interface SceneRenderer : NSObject<MTKViewDelegate>

- (instancetype)initWithMetalKitView:(MTKView*)metalKitView;

- (MTLRenderPassDescriptor*)renderPassDescriptor;

- (id<MTLCommandBuffer>)beginFrameWithNewCommandBufferAndOccupyRenderer;
- (id<MTLCommandBuffer>)createNewCommandBuffer;
- (void)scheduleReleaseRendererAfterCommandBufferCompletion:(id<MTLCommandBuffer>)commandBuffer;
- (void)scheduleCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;		// You can shedule command buffer for execution
- (void)endFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;	// Or schedule for execution and present drawable

@property (nonatomic, readonly, weak) MTKView* metalKitView;
@property (nonatomic, readonly, weak) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLLibrary> defaultLibrary;

@property (nonatomic, readonly) MTLPixelFormat defaultDepthStencilPixelFormat;
@property (nonatomic, readonly) id<MTLDepthStencilState> defaultDepthStencilState;
@property (nonatomic, readonly) NSUInteger defaultRasterSampleCount;
@property (nonatomic, readonly) MTLPixelFormat defaultColorPixelFormat;
@property (nonatomic, readonly) id<MTLRenderPipelineState> defaultDrawTexturedMeshState;
@property (nonatomic, readonly) id<MTLRenderPipelineState> defaultDrawArgumentedTexturedMeshState;
@property (nonatomic, readonly) id<MTLSamplerState> defaultLinearMipMapMaxAnisotropicSampler;

@property (nonatomic, readonly) id<MTLTexture> rock1Texture;
@property (nonatomic, readonly) id<MTLTexture> rock2Texture;
@property (nonatomic, readonly) id<MTLTexture> grass1Texture;
@property (nonatomic, readonly) id<MTLTexture> grass2Texture;
@property (nonatomic, readonly) id<MTLTexture> wood1Texture;
@property (nonatomic, readonly) id<MTLTexture> wood2Texture;
@property (nonatomic, readonly) id<MTLTexture> placeholderTexture;

@property (nonatomic, readonly) id<MTLBuffer> texturedCubeBuffer;
@property (nonatomic, readonly) NSUInteger numTexturedCubeBufferVertices;

@property (nonatomic, readonly) NSUInteger numDynamicBuffers;
@property (nonatomic, readonly) NSUInteger currentDynamicBuffer;

@property (nonatomic, readonly) dispatch_semaphore_t frameBoundarySemaphore;
@property (nonatomic, readonly) simd_float2 drawableSize;

@end

NS_ASSUME_NONNULL_END
