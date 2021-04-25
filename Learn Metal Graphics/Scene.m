//
//  Scene.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "Scene.h"

@implementation Scene
{
	VIEWPORT_UNIFORMS _local_viewportUniforms;
}

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
	_automaticallyRotateDefaultObject = YES;
	_defaultObjectRotationRate = (float)(M_PI / 4.0);
	_defaultObjectRotation = 0.0f;
	_defaultObjectModelMatrix = matrix4fIdentity();
	
	_automaticallyRotateCamera = YES;
	_automaticCameraRotationRate = (float)(M_PI / 2.5);
	
	// MARK: camera settings
	_cameraPosition = vector3fCreate(0.0f, 0.0f, 0.0f);
	_cameraRotation = vector3fCreate(M_PI / 8.0f, -M_PI / 1.2f, 0.0f);
	_cameraZOffset = 2.0f;
	_viewMatrix = matrix4fIdentity();
	
	_fovyRadians = 45.0f * M_PI / 180.0f;
	_nearZ = 0.05f;
	_farZ = 5.0f;
	_projectionMatrix = matrix4fIdentity();
	_invertedProjectionMatrix = matrix4fIdentity();
	
	_viewProjectionMatrix = matrix4fIdentity();
	
	_viewportUniforms = &_local_viewportUniforms;
	
	[self _recalculateModelMatrix];
	[self _recalculateViewMatrix];
	[self _recalculateProjectionMatrix];
}

- (void)setup
{
	// implemented by subclass
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
	const float twoPi = (float)(M_PI * 2.0);
	
	if (_automaticallyRotateDefaultObject)
	{
		_defaultObjectRotation += (float)(_defaultObjectRotationRate * timeElapsed);
		while (_defaultObjectRotation < 0.0f) {
			_defaultObjectRotation += twoPi;
		}
		while (_defaultObjectRotation > twoPi) {
			_defaultObjectRotation -= twoPi;
		}
		[self _recalculateModelMatrix];
	}
	
	if (_automaticallyRotateCamera)
	{
		vector3f rotation = _cameraRotation;
		rotation.y -= (float)(_automaticCameraRotationRate * timeElapsed);
		while (rotation.y < 0.0f) {
			rotation.y += twoPi;
		}
		while (rotation.y > twoPi) {
			rotation.y -= twoPi;
		}
		self.cameraRotation = rotation;
		[self _recalculateViewMatrix];
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

- (void)_recalculateModelMatrix
{
	_defaultObjectModelMatrix = matrix4fRotationY(_defaultObjectRotation);
}

- (void)_recalculateViewMatrix
{
	matrix4f translation = matrix4fTranslation(-_cameraPosition.x, -_cameraPosition.y, -_cameraPosition.z);
	matrix4f rotation = matrix4fIdentity();
	rotation = matrix4fMul(matrix4fRotationY(_cameraRotation.y), rotation);
	rotation = matrix4fMul(matrix4fRotationX(_cameraRotation.x), rotation);
	rotation = matrix4fMul(matrix4fRotationZ(_cameraRotation.z), rotation);
	
	matrix4f offsetTranslation = matrix4fTranslation(0.0f, 0.0f, -_cameraZOffset);
	
	_viewMatrix = matrix4fMul(offsetTranslation, matrix4fMul(rotation, translation));
	[self _recalculateViewProjectionMatrix];
	_local_viewportUniforms.view = _viewMatrix;
}

- (void)_recalculateProjectionMatrix
{
	float aspect = _sceneRenderer.drawableSize.x / _sceneRenderer.drawableSize.y;
	_projectionMatrix = matrix4fPerspectiveRightHand_MetalNDC(_fovyRadians, aspect, _nearZ, _farZ);
	_invertedProjectionMatrix = matrix4fInvert(_projectionMatrix);
	[self _recalculateViewProjectionMatrix];
	_local_viewportUniforms.projection = _projectionMatrix;
	//_local_viewportUniforms.invertedProjection = _invertedProjectionMatrix;
}

- (void)_recalculateViewProjectionMatrix
{
	_viewProjectionMatrix = matrix4fMul(_projectionMatrix, _viewMatrix);
	_local_viewportUniforms.viewProjection = _viewProjectionMatrix;
}

- (void)setCameraPosition:(vector3f)cameraPosition
{
	_cameraPosition = cameraPosition;
	[self _recalculateViewMatrix];
}

- (void)setCameraRotation:(vector3f)cameraRotation
{
	_cameraRotation = cameraRotation;
	[self _recalculateViewMatrix];
}

- (void)setCameraZOffset:(float)cameraZOffset
{
	_cameraZOffset = cameraZOffset;
	[self _recalculateViewMatrix];
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

@end
