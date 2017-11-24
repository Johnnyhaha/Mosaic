//
//  KPointAveraging.metal
//  Mosaic
//
//  Created by Johnny_L on 2017/11/16.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Thread ID == (thread position in thread group) + (thread group position in grid * threads per thread group) 线程ID ==（线程组中的线程位置）+（线程组中的线程组位置*每个线程组中的线程）


/**
 * One of two methods for calculating the K-Point Average of an entire photo at once. This particular
 * implementation requires no inter-thread communication and is best for smaller threadgroup sizes.
 *
 * This kernel is used for Photo Library pre-processing.
 *
 * Note that while this method retains the naming from 9-Point averaging, it takes in a parameter
 * with the squaresInRow = sqrt(K) for K-Point averaging.
 * 预处理 小相册的KPA计算
 */
kernel void findKPointAverage(
                              // 读入的图片资源
                             texture2d<float, access::read> image [[ texture(0) ]],
                             device uint* result [[ buffer(0) ]], // 代表着从顶点返回的顶点信息
                             device uint* params [[ buffer(1) ]],
                             uint threadId [[ thread_position_in_grid ]],
                             uint numThreads [[ threads_per_grid ]]
                                 ) {
    float4 squareColor = float4(0.0, 0.0, 0.0, 0.0);
    
    const uint squaresInRow = params[0];
    const int imageWidth = params[1];
    const int imageHeight = params[2];
    
    // 方块高与宽
    uint squareHeight = imageHeight / squaresInRow;
    uint squareWidth = imageWidth / squaresInRow;
    
    uint squareIndex = threadId;
    
    // < 5*5
    if (squareIndex < squaresInRow * squaresInRow) {
        uint squareRow = (squareIndex / squaresInRow);
        uint squareCol = squareIndex % squaresInRow;
        
        for (uint row = 0; row < squareHeight; row += 1) {
            uint pixelRow = squareHeight * squareRow + row;
            
            //Now, process that row of the square.方块每行 像素
            for (uint delta = 0; delta < squareWidth; delta++) {
                uint pixelCol = squareWidth * squareCol + delta;
                // 读取每一格的每一个像素的RGBA
                uint2 coord = uint2(pixelCol, pixelRow);
                squareColor += image.read(coord);
            }
        }
        
        squareColor.r = squareColor.r / float(squareHeight * squareWidth) * 100.0;
        squareColor.g = squareColor.g  / float(squareHeight * squareWidth) * 100.0;
        squareColor.b = squareColor.b  / float(squareHeight * squareWidth) * 100.0;
        result[squareIndex * 3 + 0] = uint(squareColor.r);
        result[squareIndex * 3 + 1] = uint(squareColor.g);
        result[squareIndex * 3 + 2] = uint(squareColor.b);
    }
}


/**
 * This kernel is used to split up the given photo texture into a grid (as determined by gridSize)
 * and perform K-Point averaging on each square in the grid in one kernel call. This has a significant
 * performance advantage to calling either of the above kernels for each square in the grid.
 *
 * This kernel is used when the user picks a reference photo to help match photos to sections
 * of the reference image.
 *
 * Note that while this method retains the naming from 9-Point averaging, it takes in a parameter
 * with the gridsAcross = sqrt(K) for K-Point averaging.
 */
// 将选择的照片纹理分割成网格，对每个网格求KPA
kernel void findPhotoKPointAverage(
                                      texture2d<float, access::read> image [[ texture(0) ]],
                                      device uint* params [[ buffer(0) ]],
                                      device uint* result [[ buffer(1) ]],
                                      uint threadId [[ thread_position_in_grid ]],
                                      uint numThreads [[ threads_per_grid ]]
                                      ) {
    
    const uint gridSize = params[0]; // 网格方块
    const uint numRows = params[1];
    const uint numCols = params[2];
    const uint gridsAcross = params[3]; //方块间隔
    
    // The total number of K-point squares in the entire photo
    uint KPointSquares = numRows * numCols * gridsAcross * gridsAcross;
    
    for (uint squareIndex = threadId; squareIndex < KPointSquares; squareIndex += numThreads) {
        float4 sum = float4(0.0, 0.0, 0.0, 0.0);
        // 网格方块
        uint gridSquareIndex = squareIndex / (gridsAcross * gridsAcross);
        uint gridSquareX = (gridSquareIndex % numCols) * gridSize;
        uint gridSquareY = (gridSquareIndex / numCols) * gridSize;
        
        uint KPointIndex = squareIndex % (gridsAcross * gridsAcross);
        uint KPointSize = gridSize / gridsAcross;
        // 实际索引
        uint KPointX = gridSquareX + (( KPointIndex % gridsAcross) * KPointSize);
        uint KPointY = gridSquareY + (( KPointIndex / gridsAcross) * KPointSize);
        
        for (uint deltaY = 0; deltaY < KPointSize; deltaY++) {
            for (uint deltaX = 0; deltaX < KPointSize; deltaX++) {
                uint2 coord = uint2(KPointX + deltaX, KPointY + deltaY);
                sum += image.read(coord);
            }
        }
        sum.r = sum.r / (KPointSize * KPointSize) * 100.0;
        sum.g = sum.g  / (KPointSize * KPointSize) * 100.0;
        sum.b = sum.b  / (KPointSize * KPointSize) * 100.0;
        
        result[squareIndex * 3 + 0] = uint(sum.r);
        result[squareIndex * 3 + 1] = uint(sum.g);
        result[squareIndex * 3 + 2] = uint(sum.b);
    }
}

/**
 * This kernel is used as the final step before drawing the completed photo mosaic. Once
 * we have K-Point Averaging information for both the reference photo and the photo library
 * (from KPA Storage) given as uint32 sequences, it performs a reduction on the "distance"
 * between each vertex and maps the result buffer to the index of the nearest neighbor
 * with respect to the given K vectors.
 */
kernel void findNearestMatches(
                               device uint* refKs [[ buffer(0) ]],
                               device uint* otherKs [[ buffer(1) ]],
                               device uint* result  [[ buffer(2) ]],
                               device uint* params  [[ buffer(3) ]],
                               uint threadId [[ thread_position_in_grid ]],
                               uint numThreads [[ threads_per_grid ]]
                               ) {
    const int numCells = params[0];
    const int pointsPerK = numCells * 3; // 25 * 3
    int refKCount = params[1] / pointsPerK; // 网格照片
    int otherKCount = params[2] / pointsPerK; // 存储照片
    
    for (int refKIndex = threadId; refKIndex < refKCount; refKIndex += numThreads) {
        uint minKId = 0;
        float minDiff = 0.0;
        for (int otherIndex = 0; otherIndex < otherKCount; otherIndex++) {
            float diff = 0.0;
            for (int delta = 0; delta < pointsPerK; delta++) {
                diff += (float(refKs[refKIndex*pointsPerK + delta]) - float(otherKs[otherIndex*pointsPerK + delta])) *
                (float(refKs[refKIndex*pointsPerK + delta]) - float(otherKs[otherIndex*pointsPerK + delta]));
            }
            // 从相册中找出与选择照片RGB相差最小的相片的索引
            if (minKId == 0 || diff < minDiff) {
                minKId = otherIndex;
                minDiff = diff;
            }
        }
        result[refKIndex] = minKId;
    }
}


