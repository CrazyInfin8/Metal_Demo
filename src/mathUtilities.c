//
// Created by CrazyInfin8 on 6/30/24.
//

#include "mathUtilities.h"
#include "types.h"

#include <simd/simd.h>

// `PI` is π, a mathematical constant useful for rotation and trigonometry.
//
// This is equivalent to 180 degrees of rotation or halfway around a circle.
const float32 PI = 3.141592653589793238462643383279502884197169399375105820974f;

// `PI_2` is π multiplied by 2.
//
// This is equivalent to 360 degrees of rotation or the full rotation of a circle.
const float32 PI_2 = 6.2831853071795864769252867665590057683943387987502116419f;

// `TO_DEG` helps to convert radians to degrees by simply multiplying radians
// with this value.
//
// It is equal to `180 / π`.
const float32 TO_DEG = 57.2957795130823208767981548141051703324054724665643215f;

// `TO_RAD` helps to convert degrees to radians by simply multiplying degrees
// with this value.
//
// It is equal to `π / 180`.
const float32 TO_RAD = 0.01745329251994329576923690768488612713442871888541725f;

simd_float4x4 setMatrix4x4(
        float m00, float m10, float m20, float m30,
        float m01, float m11, float m21, float m31,
        float m02, float m12, float m22, float m32,
        float m03, float m13, float m23, float m33) {
    return (simd_float4x4) {
            {
                    {m00, m01, m02, m03},
                    {m10, m11, m12, m13},
                    {m20, m21, m22, m23},
                    {m30, m31, m32, m33}
            }
    };
}

simd_float4x4 translationMatrix4x4(float tx, float ty, float tz) {
    return setMatrix4x4(
            1.0f, 0.0f, 0.0f, tx,
            0.0f, 1.0f, 0.0f, ty,
            0.0f, 0.0f, 1.0f, tz,
            0.0f, 0.0f, 0.0f, 1
    );
}

simd_float4x4 rotationMatrix4x4(float angle, float x, float y, float z) {
    float c = cosf(angle);
    float s = sinf(angle);
    float t = 1.0f - c;

    return setMatrix4x4(
            x * x * t + c, y * x * t + z * s, x * z * t - y * s, 0.0f,
            x * y * t - z * s, y * y * t + c, y * z * t + x * s, 0.0f,
            x * z * t + y * s, y * z * t - x * s, z * z * t + c, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f
    );
}

simd_float4x4 matrixPerspectiveRightHand(float fovYRadians, float aspect, float nearZ, float farZ) {
    float yScale = 1.0f / tanf(fovYRadians * 0.5f);
    float xScale = yScale / aspect;
    float zRange = farZ / (nearZ - farZ);
    return setMatrix4x4(
            xScale, 0.0f, 0.0f, 0.0f,
            0.0f, yScale, 0.0f, 0.0f,
            0.0f, 0.0f, zRange, nearZ * zRange,
            0.0f, 0.0f, -1.0f, 0.0f
    );
}