//
// Created by CrazyInfin8 on 6/30/24.
//

#ifndef METAL_DEMO_MATHUTILITIES_H
#define METAL_DEMO_MATHUTILITIES_H

#include "types.h"
#include <simd/simd.h>

// `PI` is π, a mathematical constant useful for rotation and trigonometry.
//
// This is equivalent to 180 degrees of rotation or halfway around a circle.
extern const float32 PI;

// `PI_2` is π multiplied by 2.
//
// This is equivalent to 360 degrees of rotation or the full rotation of a circle.
extern const float32 PI_2;

// `TO_DEG` helps to convert radians to degrees by simply multiplying radians
// with this value.
//
// It is equal to `180 / π`.
extern const float32 TO_DEG;

// `TO_RAD` helps to convert degrees to radians by simply multiplying degrees
// with this value.
//
// It is equal to `π / 180`.
extern const float32 TO_RAD;

simd_float4x4 setMatrix4x4(
        float m00, float m10, float m20, float m30,
        float m01, float m11, float m21, float m31,
        float m02, float m12, float m22, float m32,
        float m03, float m13, float m23, float m33);

simd_float4x4 translationMatrix4x4(float tx, float ty, float tz);

simd_float4x4  rotationMatrix4x4(float angle, float x, float y, float z);

simd_float4x4 matrixPerspectiveRightHand(float fovYRadians, float aspect, float nearZ, float farZ);

#endif //METAL_DEMO_MATHUTILITIES_H
