//
// Created by CrazyInfin8 on 6/26/24.
//

#ifndef METAL_DEMO_VERTEXDATA_H
#define METAL_DEMO_VERTEXDATA_H

#pragma once

#import <simd/simd.h>

typedef struct VertexData {
    simd_float4 position;
    simd_float2 textureCoordinate;
} VertexData;

typedef struct Transformation {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 perspectiveMatrix;
} Transformation;

#endif //METAL_DEMO_VERTEXDATA_H
