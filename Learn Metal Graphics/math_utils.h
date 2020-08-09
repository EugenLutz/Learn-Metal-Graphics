//
//  math_utils.h
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#ifndef math_utils_h
#define math_utils_h

#include <simd/simd.h>

simd_float4x4 matrixRotation(float radians, float x, float y, float z);
simd_float4x4 matrixScale(float sx, float sy, float sz);
simd_float4x4 matrixTranslation(float tx, float ty, float tz);
simd_float4x4 matrixPerspectiveRightHand(float fovyRadians, float aspect, float nearZ, float farZ);

#endif /* math_utils_h */
