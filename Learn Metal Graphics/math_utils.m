//
//  math_utils.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 08.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#include "math_utils.h"

static simd_float4x4 matrix_make_rows(float m00, float m10, float m20, float m30,
									  float m01, float m11, float m21, float m31,
									  float m02, float m12, float m22, float m32,
									  float m03, float m13, float m23, float m33)
{
	return (simd_float4x4){ {
		{ m00, m01, m02, m03 },		// each line here provides column data
		{ m10, m11, m12, m13 },
		{ m20, m21, m22, m23 },
		{ m30, m31, m32, m33 } } };
}

simd_float4x4 matrixRotation(float radians, float x, float y, float z)
{
	simd_float3 axis = simd_normalize(simd_make_float3(x, y, z));
	float ct = cosf(radians);
	float st = sinf(radians);
	float ci = 1 - ct;
	x = axis.x;
	y = axis.y;
	z = axis.z;
	return matrix_make_rows(
						ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st, 0,
					y * x * ci + z * st,     ct + y * y * ci, y * z * ci - x * st, 0,
					z * x * ci - y * st, z * y * ci + x * st,     ct + z * z * ci, 0,
									  0,                   0,                   0, 1);
}

simd_float4x4 matrixScale(float sx, float sy, float sz) {
	return matrix_make_rows(sx,  0,  0, 0,
							 0, sy,  0, 0,
							 0,  0, sz, 0,
							 0,  0,  0, 1 );
}

simd_float4x4 matrixTranslation(float tx, float ty, float tz) {
	return matrix_make_rows(1, 0, 0, tx,
							0, 1, 0, ty,
							0, 0, 1, tz,
							0, 0, 0,  1 );
}

simd_float4x4 matrixPerspectiveRightHand(float fovyRadians, float aspect, float nearZ, float farZ)
{
	float ys = 1 / tanf(fovyRadians * 0.5);
	float xs = ys / aspect;
	float zs = farZ / (nearZ - farZ);
	return matrix_make_rows(xs,  0,  0,          0,
							 0, ys,  0,          0,
							 0,  0, zs, nearZ * zs,
							 0,  0, -1,          0 );
}
