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
#include "SharedUniforms.h"
#include "foundation.h"

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

@property (nonatomic) BOOL automaticallyRotateDefaultObject;
@property (nonatomic) float defaultObjectRotationRate;
@property (nonatomic) float defaultObjectRotation;
@property (nonatomic, readonly) matrix4f defaultObjectModelMatrix;

@property (nonatomic) BOOL automaticallyRotateCamera;
@property (nonatomic) float automaticCameraRotationRate;
@property (nonatomic) vector3f cameraPosition;
@property (nonatomic) vector3f cameraRotation;
@property (nonatomic) float cameraZOffset;
@property (nonatomic, readonly) matrix4f viewMatrix;

@property (nonatomic) float fovyRadians;
@property (nonatomic) float nearZ;
@property (nonatomic) float farZ;
@property (nonatomic, readonly) matrix4f projectionMatrix;

@property (nonatomic, readonly) matrix4f viewProjectionMatrix;

@property (nonatomic, readonly) VIEWPORT_UNIFORMS* viewportUniforms;

@end

NS_ASSUME_NONNULL_END
