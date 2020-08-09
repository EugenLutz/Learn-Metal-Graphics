//
//  Scene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "Scene.h"
#include "math_utils.h"

@implementation Scene

- (instancetype)initWithSceneRenderer:(SceneRenderer*)sceneRenderer
{
	self = [super init];
	if (self)
	{
		_sceneRenderer = sceneRenderer;
		[self _initBaseSceneCommon];
	}
	return self;
}

- (void)_initBaseSceneCommon
{
	_automaticallyRotateScene = YES;
	_automaticRotationRate = (float)(M_PI / 10.0);
	
	
	// MARK: camera settings
	_cameraPosition = simd_make_float3(0.0f, 0.0f, 0.0f);
	_cameraRotation = simd_make_float3(M_PI / 8.0f, 0.0f, 0.0f);
	_cameraZOffset = 2.0f;
	_viewMatrix = matrix_identity_float4x4;
	
	_fovyRadians = 45.0f * M_PI / 180.0f;
	_nearZ = 0.05f;
	_farZ = 100.0f;
	_projectionMatrix = matrix_identity_float4x4;
	
	_viewProjectionMatrix = matrix_identity_float4x4;
	
	[self _recalculateViewMatrix];
	[self _recalculateProjectionMatrix];
}

- (void)drawableResized:(simd_float2)size
{
	[self _recalculateProjectionMatrix];
	
	// implemented by subclass
}

- (void)keyDown:(unsigned int)keyCode
{
	// implemented by subclass
}

- (void)keyUp:(unsigned int)keyCode
{
	// implemented by subclass
}

- (void)drawWithCommandQueue:(id<MTLCommandQueue>)commandQueue timeElapsed:(double)timeElapsed
{
	if (_automaticallyRotateScene)
	{
		simd_float3 rotation = _cameraRotation;
		rotation.y -= (float)(_automaticRotationRate * timeElapsed);
		self.cameraRotation = rotation;
	}
	
	id<MTLCommandBuffer> commandBuffer = [_sceneRenderer beginFrameWithNewCommandBufferAndOccupyRenderer];
	[_sceneRenderer scheduleReleaseRendererAfterCommandBufferCompletion:commandBuffer];
	
	[self drawWithCommandBuffer:commandBuffer timeElapsed:timeElapsed];
	
	[_sceneRenderer endFrameWithCommandBuffer:commandBuffer];
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer timeElapsed:(double)timeElapsed
{
	// Get current render pass descriptor
	MTLRenderPassDescriptor* currentRenderPassDescriptor = _sceneRenderer.renderPassDescriptor;
	if (!currentRenderPassDescriptor) {
		return;
	}
	
	// Create and draw to render command encoder
	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:currentRenderPassDescriptor];
	[self drawWithRenderCommandEncoder:encoder timeElapsed:timeElapsed];
	[encoder endEncoding];
}

- (void)drawWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder timeElapsed:(double)timeElapsed
{
	// implemented by subclass
}

// MARK: - Properties

- (void)_recalculateViewMatrix
{
	simd_float4x4 translation = matrixTranslation(-_cameraPosition.x, -_cameraPosition.y, -_cameraPosition.z);
	simd_float4x4 rotation = matrix_identity_float4x4;
	rotation = matrix_multiply(matrixRotation(_cameraRotation.y, 0.0f, 1.0f, 0.0f), rotation);
	rotation = matrix_multiply(matrixRotation(_cameraRotation.x, 1.0f, 0.0f, 0.0f), rotation);
	rotation = matrix_multiply(matrixRotation(_cameraRotation.z, 0.0f, 0.0f, 1.0f), rotation);
	
	simd_float4x4 offsetTranslation = matrixTranslation(0.0f, 0.0f, -_cameraZOffset);
	
	self.viewMatrix = matrix_multiply(offsetTranslation, matrix_multiply(rotation, translation));
}

- (void)_recalculateProjectionMatrix
{
	float aspect = _sceneRenderer.drawableSize.x / _sceneRenderer.drawableSize.y;
	self.projectionMatrix = matrixPerspectiveRightHand(_fovyRadians, aspect, _nearZ, _farZ);
}

- (void)_recalculateViewProjectionMatrix
{
	_viewProjectionMatrix = simd_mul(_projectionMatrix, _viewMatrix);
}

- (void)setCameraPosition:(simd_float3)cameraPosition
{
	_cameraPosition = cameraPosition;
	[self _recalculateViewMatrix];
}

- (void)setCameraRotation:(simd_float3)cameraRotation
{
	_cameraRotation = cameraRotation;
	[self _recalculateViewMatrix];
}

- (void)setCameraZOffset:(float)cameraZOffset
{
	_cameraZOffset = cameraZOffset;
	[self _recalculateViewMatrix];
}

- (void)setViewMatrix:(simd_float4x4)viewMatrix
{
	_viewMatrix = viewMatrix;
	[self _recalculateViewProjectionMatrix];
}

- (void)setFovyRadians:(float)fovyRadians
{
	_fovyRadians = fovyRadians;
	[self _recalculateProjectionMatrix];
}

- (void)setNearZ:(float)nearZ
{
	_nearZ = nearZ;
	[self _recalculateProjectionMatrix];
}

- (void)setFarZ:(float)farZ
{
	_farZ = farZ;
	[self _recalculateProjectionMatrix];
}

- (void)setProjectionMatrix:(simd_float4x4)projectionMatrix
{
	_projectionMatrix = projectionMatrix;
	[self _recalculateViewProjectionMatrix];
}

@end
