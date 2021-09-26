//
//  ArgumentBuffersScene.m
//  Learn Metal Graphics
//
//  Created by Evgenij on 24.09.21.
//  Copyright © 2021 Eugene Lutz. All rights reserved.
//

#import "ArgumentBuffersScene.h"

@implementation ArgumentBuffersScene
{
    NSUInteger numObjects;
    
    simd_float3* locations; // Locations of every object
    simd_float3* rotations; // Rotations of every object
    simd_float4* rotVectors; // Rotation vectors of every object
    NSArray<id<MTLBuffer>>* modelBuffers;   // Each array is used sequentially every frame, contains model matrices (composed of locations[i] and rotations[i])
    NSArray<id<MTLBuffer>>* viewProjectionBuffers;  // Contains view-projection matrix
    id<MTLBuffer> transformBuffer;          // it will be used to write data
    id<MTLComputePipelineState> computePipelineState;   // It will be used to multiply data and write it to the transformBuffer
    id<MTLTexture> drawTexture;
    
    id<MTLFence> computeBarrier;
    
    MTLRenderPassDescriptor* renderPassDescriptor;
    id<MTLRenderPipelineState> renderState;
    
    NSMutableArray<id<MTLBuffer>>* vsArgumentBuffers;
    NSMutableArray<id<MTLBuffer>>* fsArgumentBuffers;
}

- (instancetype)initWithSceneRenderer:(SceneRenderer *)sceneRenderer {
    self = [super initWithSceneRenderer:sceneRenderer];
    if (self) {
        _useArgumentBuffers = YES;
        
        numObjects = 4000;
        const float startHeight = 0;
        const float endHeight = 10;
        const float startRadius = 1;
        const float endRadius = 150;
        const float step = M_PI;
        float currentAngle = 0;
        
        const float rotationStep = M_PI / 3;
        float currentRotation = 0;
        
        // Initialize randomizer
        srand(0);
        
        locations = malloc(sizeof(simd_float3) * numObjects);
        rotations = malloc(sizeof(simd_float3) * numObjects);
        rotVectors = malloc(sizeof(simd_float4) * numObjects);
        for (NSUInteger i = 0; i < numObjects; i++) {
            // Generate location
            float coefficient = 1.0 / (float)(numObjects - 1) * (float)i;
            float circleCoefficient = (1.0 - cosf(M_PI * coefficient));
            float height = startHeight + circleCoefficient * (endHeight - startHeight);
            float radius = startRadius + coefficient * (endRadius - startRadius);
            currentAngle += step * (startRadius / radius);
            matrix4f mat = matrix4fRotationY(currentAngle);
            locations[i] = simd_mul(mat, simd_make_float4(0, height, radius, 1.0)).xyz;
            
            // Generate rotation
            currentRotation += rotationStep;
            rotations[i] = currentRotation;
            
            // Generate rotation speed
            float rotX = (0.7f + 0.3f / 100.0f * (float)(rand() % 100)) * (rand() % 100 > 50 ? 1.0f : -1.0f);
            float rotY = (0.7f + 0.3f / 100.0f * (float)(rand() % 100)) * (rand() % 100 > 50 ? 1.0f : -1.0f);
            float rotZ = (0.7f + 0.3f / 100.0f * (float)(rand() % 100)) * (rand() % 100 > 50 ? 1.0f : -1.0f);
            float rot = (M_PI) / 100.0f * (float)(rand() % 100);
            rotVectors[i] = simd_make_float4(rotX, rotY, rotZ, rot);
        }
    }
    return self;
}

- (void)dealloc {
    free(locations);
    free(rotations);
    free(rotVectors);
}

- (void)setup {
    self.automaticallyRotateCamera = YES;
    self.automaticCameraRotationRate = M_PI / 128;
    self.farZ = 500;
    self.cameraZOffset = 100;
    
    id<MTLDevice> device = self.sceneRenderer.device;
    id<MTLLibrary> library = self.sceneRenderer.defaultLibrary;
    
    // Create uniform buffers
    NSMutableArray<id<MTLBuffer>>* _modelBuffers = [[NSMutableArray alloc] init];
    NSMutableArray<id<MTLBuffer>>* _viewProjectionBuffers = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < self.sceneRenderer.numDynamicBuffers; i++) {
        id<MTLBuffer> modelBuffer = [device newBufferWithLength:sizeof(simd_float4x4) * numObjects options:MTLResourceStorageModeShared];
        [_modelBuffers addObject:modelBuffer];
        
        id<MTLBuffer> viewProjectionBuffer = [device newBufferWithLength:sizeof(simd_float4x4) options:MTLResourceStorageModeShared];
        [_viewProjectionBuffers addObject:viewProjectionBuffer];
    }
    modelBuffers = _modelBuffers;
    viewProjectionBuffers = _viewProjectionBuffers;
    
    transformBuffer = [device newBufferWithLength:sizeof(simd_float4x4) * numObjects options:MTLResourceStorageModePrivate];
    
    computePipelineState = [device newComputePipelineStateWithFunction:[library newFunctionWithName:@"processCubeUniforms_cs"] error:nil];
    assert(computePipelineState);
    
    
    drawTexture = self.sceneRenderer.rock2Texture;
    
    
    computeBarrier = [device newFence];
    
    
    // Create render pass descriptor
    renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    renderPassDescriptor.depthAttachment.clearDepth = 1.0;
    renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
    renderPassDescriptor.depthAttachment.texture = nil;
    renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionClear;
    renderPassDescriptor.stencilAttachment.clearStencil = 0;
    renderPassDescriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
    renderPassDescriptor.stencilAttachment.texture = nil;
    
    
    // Create pipeline state
    MTLRenderPipelineDescriptor* renderDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    renderDescriptor.label = @"Argument buffer";
    renderDescriptor.colorAttachments[0].pixelFormat = self.sceneRenderer.defaultColorPixelFormat;
    renderDescriptor.depthAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
    renderDescriptor.stencilAttachmentPixelFormat = self.sceneRenderer.defaultDepthStencilPixelFormat;
    renderDescriptor.vertexFunction = [library newFunctionWithName:@"texturedCube_arg_vs"];
    assert(renderDescriptor.vertexFunction);
    renderDescriptor.fragmentFunction = [library newFunctionWithName:@"texturedCube_arg_fs"];
    assert(renderDescriptor.fragmentFunction);
    renderState = [device newRenderPipelineStateWithDescriptor:renderDescriptor error:nil];
    assert(renderState);
    
    // Create argument buffers for vertex function
    id<MTLArgumentEncoder> vabEncoder = [renderDescriptor.vertexFunction newArgumentEncoderWithBufferIndex:0];
    vsArgumentBuffers = [[NSMutableArray alloc] initWithCapacity:numObjects];
    for (NSUInteger i = 0; i < numObjects; i++) {
        id<MTLBuffer> buffer = [device newBufferWithLength:vabEncoder.encodedLength options:MTLResourceStorageModeShared];
        [vsArgumentBuffers addObject:buffer];
        [vabEncoder setArgumentBuffer:buffer offset:0];
        
        unsigned int* instanceId = [vabEncoder constantDataAtIndex:0];
        *instanceId = (unsigned int)i;
        
        [vabEncoder setBuffer:self.sceneRenderer.cubeNUVBuffer offset:0 atIndex:1];
        [vabEncoder setBuffer:transformBuffer offset:0 atIndex:2];
    }
    
    // Create argument buffers for fragment function
    id<MTLArgumentEncoder> fabEncoder = [renderDescriptor.fragmentFunction newArgumentEncoderWithBufferIndex:0];
    fsArgumentBuffers = [[NSMutableArray alloc] initWithCapacity:numObjects];
    for (NSUInteger i = 0; i < numObjects; i++) {
        id<MTLBuffer> buffer = [device newBufferWithLength:fabEncoder.encodedLength options:MTLResourceStorageModeShared];
        [fsArgumentBuffers addObject:buffer];
        [fabEncoder setArgumentBuffer:buffer offset:0];
        
        [fabEncoder setTexture:drawTexture atIndex:0];
        [fabEncoder setSamplerState:self.sceneRenderer.anisotropicSampler_argument atIndex:1];
        
        simd_float3* lightLocation = [fabEncoder constantDataAtIndex:2];
        *lightLocation = simd_make_float3(0, 0, 0);
        
        simd_float3* lightColor = [fabEncoder constantDataAtIndex: 3];
        *lightColor = simd_make_float3(0.8, 0.8, 0);
    }
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer timeElapsed:(double)timeElapsed {
    NSUInteger currentBufferIndex = self.sceneRenderer.currentDynamicBuffer;
    
    // Fill model buffer with model matrices
    id<MTLBuffer> modelBuffer = modelBuffers[currentBufferIndex];
    simd_float4x4* modelBufferData = modelBuffer.contents;
    for (NSUInteger i = 0; i < numObjects; i++) {
        simd_float3 rotation = rotations[i];
        simd_float4 vector = rotVectors[i];
        rotation.x += vector.x * vector.w * timeElapsed;
        rotation.y += vector.y * vector.w * timeElapsed;
        rotation.z += vector.z * vector.w * timeElapsed;
        rotations[i] = rotation;
        
        simd_float3 location = locations[i];
        
        matrix4f transform = matrix4fIdentity();
        transform = simd_mul(matrix4fRotationY(rotation.y), transform);
        transform = simd_mul(matrix4fRotationX(rotation.x), transform);
        transform = simd_mul(matrix4fRotationZ(rotation.z), transform);
        transform = simd_mul(matrix4fTranslationFromVector3f(location), transform);
        modelBufferData[i] = transform;
    }
    
    // Set view-projection matrix
    id<MTLBuffer> viewProjectionBuffer = viewProjectionBuffers[currentBufferIndex];
    simd_float4x4* viewProjectionBufferData = viewProjectionBuffer.contents;
    *viewProjectionBufferData = self.viewProjectionMatrix;
    
    // Schedule buffer update
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder pushDebugGroup:@"Calculating model-view-projection matrices"];
    [computeEncoder setComputePipelineState:computePipelineState];
    [computeEncoder setBuffer:modelBuffer offset:0 atIndex:0];
    [computeEncoder setBuffer:viewProjectionBuffer offset:0 atIndex:1];
    [computeEncoder setBuffer:transformBuffer offset:0 atIndex:2];
    MTLSize gridSize = MTLSizeMake(numObjects, 1, 1);
    NSUInteger threadGroupSize = computePipelineState.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > numObjects) {
        threadGroupSize = numObjects;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);
    [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [computeEncoder updateFence:computeBarrier]; // Allow rendering after compute execution
    [computeEncoder popDebugGroup];
    [computeEncoder endEncoding];
    
    
    // Draw primitives
    renderPassDescriptor.colorAttachments[0].texture = self.sceneRenderer.currentDrawableInRenderLoop.texture;
    renderPassDescriptor.depthAttachment.texture = self.sceneRenderer.renderPassDescriptor.depthAttachment.texture;
    renderPassDescriptor.stencilAttachment.texture = self.sceneRenderer.renderPassDescriptor.stencilAttachment.texture;
    id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    assert(renderCommandEncoder);
    [renderCommandEncoder pushDebugGroup:@"Draw objecs"];
    [renderCommandEncoder waitForFence:computeBarrier beforeStages:MTLRenderStageVertex];   // Wait until compute finishes
    
    [renderCommandEncoder setRenderPipelineState:renderState];
    [renderCommandEncoder setDepthStencilState:self.sceneRenderer.defaultDepthStencilState];
    [renderCommandEncoder setCullMode:MTLCullModeBack];
    [renderCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [renderCommandEncoder useResource:self.sceneRenderer.cubeNUVBuffer usage:MTLResourceUsageRead];
    [renderCommandEncoder useResource:transformBuffer usage:MTLResourceUsageRead];
    [renderCommandEncoder useResource:drawTexture usage:MTLResourceUsageSample];
    //[renderCommandEncoder useResource:self.sceneRenderer.anisotropicSampler_argument usage:MTLResourceUsageRead];
    for (NSUInteger i = 0; i < numObjects; i++) {
        [renderCommandEncoder setVertexBuffer:vsArgumentBuffers[i] offset:0 atIndex:0];
        [renderCommandEncoder setFragmentBuffer:fsArgumentBuffers[i] offset:0 atIndex:0];
        [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.sceneRenderer.numCubeNUVBufferVertices];
    }
    [renderCommandEncoder popDebugGroup];
    [renderCommandEncoder endEncoding];
}

//- (void)drawWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder timeElapsed:(double)timeElapsed {
//    if (!_useArgumentBuffers) {
//        // Do nothing at the moment
//        return;
//    }
//
//    /*[renderCommandEncoder setRenderPipelineState:renderState];
//    [renderCommandEncoder setDepthStencilState:self.sceneRenderer.defaultDepthStencilState];
//
//    for (NSUInteger i = 0; i < numObjects; i++) {
//        //
//    }*/
//}

@end
