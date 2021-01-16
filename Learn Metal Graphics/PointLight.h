//
//  PointLight.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 16.01.21.
//  Copyright © 2021 Eugene Lutz. All rights reserved.
//

#ifndef PointLight_h
#define PointLight_h

#include <simd/simd.h>

typedef struct POINT_LIGHT
{
	simd_float3 location;
	simd_float3 color;
	float radius;
}
POINT_LIGHT;

#endif /* PointLight_h */
