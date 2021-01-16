//
//  Scene.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

@import Foundation;
@import Metal;
@import MetalKit;
@import MetalPerformanceShaders;
#import "SceneRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface Scene : NSObject

- (instancetype)initWithSceneRenderer:(SceneRenderer*)sceneRenderer;

- (void)setup;
- (void)drawableResized:(simd_float2)size;

- (void)keyDown:(unsigned int)keyCode;
- (void)keyUp:(unsigned int)keyCode;

- (void)drawWithCommandQueue:(id<MTLCommandQueue>)commandQueue timeElapsed:(double)timeElapsed;
- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer timeElapsed:(double)timeElapsed;
- (void)drawWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder timeElapsed:(double)timeElapsed;

@property (nonatomic, readonly, weak) SceneRenderer* sceneRenderer;

@property (nonatomic) BOOL automaticallyRotateScene;
@property (nonatomic) float automaticRotationRate;

@property (nonatomic) simd_float3 cameraPosition;
@property (nonatomic) simd_float3 cameraRotation;
@property (nonatomic) float cameraZOffset;
@property (nonatomic, readonly) simd_float4x4 viewMatrix;

@property (nonatomic) float fovyRadians;
@property (nonatomic) float nearZ;
@property (nonatomic) float farZ;
@property (nonatomic, readonly) simd_float4x4 projectionMatrix;

@property (nonatomic, readonly) simd_float4x4 viewProjectionMatrix;

@end

NS_ASSUME_NONNULL_END
