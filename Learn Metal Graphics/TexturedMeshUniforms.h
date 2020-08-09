//
//  TexturedMeshUniforms.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#ifndef TexturedMeshUniforms_h
#define TexturedMeshUniforms_h

#include <simd/simd.h>
#include "TexturedVertex.h"

typedef struct TEXTURED_VERTEX_UNIFORMS
{
	simd_float4x4 modelViewProjection;
}
TEXTURED_VERTEX_UNIFORMS;

#endif /* TexturedMeshUniforms_h */
