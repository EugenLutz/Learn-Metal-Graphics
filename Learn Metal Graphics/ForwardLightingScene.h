//
//  ForwardLightingScene.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 07.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "Scene.h"

NS_ASSUME_NONNULL_BEGIN

@interface ForwardLightingScene : Scene

@property (nonatomic) BOOL useInstanceIndex;

@property (nonatomic) TEXTURED_VERTEX_UNIFORMS vertexUniforms;
@property (nonatomic) MESH_NUV_FRAGMENT_UNIFORMS fragmentUniforms;

@end

NS_ASSUME_NONNULL_END
