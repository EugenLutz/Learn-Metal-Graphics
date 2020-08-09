//
//  TexturedVertex.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#ifndef TexturedVertex_h
#define TexturedVertex_h

#include <simd/simd.h>

typedef struct TEXTURED_VERTEX
{
	simd_float3 position;
	simd_float2 uv;
}
TEXTURED_VERTEX;

#endif /* TexturedVertex_h */
