//
//  VertexNUV.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#ifndef VertexNUV_h
#define VertexNUV_h

#include <simd/simd.h>

typedef struct VERTEX_NUV
{
	simd_float3 position;
	simd_float3 normal;
	simd_float2 uv;
}
VERTEX_NUV;

#endif /* VertexNUV_h */
