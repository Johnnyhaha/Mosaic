//
//  MetalPipeline.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/15.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Metal
import MetalKit

// 9.Metal 管道---------------------------------------------
// (1)Metal GPU Frame Capture Enabled (2)Metal API Validation Enabled
class MetalPipeline {
    let device : MTLDevice
    let commandQueue : MTLCommandQueue
    let library: MTLLibrary
    let KPointAverage : MTLFunction
//    let KPointAverageAcrossThreadGroups : MTLFunction
    let PhotoKPointAverage : MTLFunction
    let FindNearestMatches : MTLFunction
    var pipelineState : MTLComputePipelineState? = nil
    var photoPipelineState : MTLComputePipelineState? = nil
    var matchesPipelineState : MTLComputePipelineState? = nil
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()! // 1支持Metal的系统默认设备
        self.commandQueue = self.device.makeCommandQueue() // 2线程安全的渲染队列，可以支持多个 CommandBuffer 同时编码。
        self.library = self.device.newDefaultLibrary()! // 3在默认Metal库创建新库 构建渲染管道时将使用这个库
        
        // 通过名字获取函数  编译着色器shader
        // 小相册KPA
        self.KPointAverage = self.library.makeFunction(name: "findKPointAverage")!
//        self.KPointAverageAcrossThreadGroups = self.library.makeFunction(name: "findKPointAverageAcrossThreadGroups")!
        //参考照片KPA
        self.PhotoKPointAverage = self.library.makeFunction(name: "findPhotoKPointAverage")!
        //匹配功能
        self.FindNearestMatches = self.library.makeFunction(name: "findNearestMatches")!
        // 创建设置了函数和像素格式的管道描述器
        do {
            self.pipelineState = try self.device.makeComputePipelineState(function: self.KPointAverage)
//            self.pipelineState = try self.device.makeComputePipelineState(function: self.KPointAverageAcrossThreadGroups)
            self.photoPipelineState = try self.device.makeComputePipelineState(function: self.PhotoKPointAverage)
            self.matchesPipelineState = try self.device.makeComputePipelineState(function: self.FindNearestMatches)
        } catch {
            print("Error initializing pipeline state!")
        }
    }
    
    // 加载图像纹理数据
    func getImageTexture(image: CGImage) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: self.device)
        return try textureLoader.newTexture(with: image)
    }
    
    
    // 预处理所有图像的KPA
    //    先构造 MTLCommandBuffer ，再配置 CommandEncoder ，包括配置资源文件，渲染管线等，再通过 CommandEncoder 进行编码，最后才能提交到队列中去
    func processImageTexture(texture: MTLTexture, width: Int, height: Int, threadWidth: Int, complete : @escaping ([UInt32]) -> Void) {
        let commandBuffer = self.commandQueue.makeCommandBuffer() // 命令缓冲区
        let commandEncoder = commandBuffer.makeComputeCommandEncoder() // 命令编码器
        
        // pipelineState 获得像素RGBA
        commandEncoder.setComputePipelineState(self.pipelineState!)
        commandEncoder.setTexture(texture, at: 0)
        
        // 为了真正的绘制几何图形，我们告诉 Metal 要绘制的形状 (三角形) 和缓冲区中顶点的数量
        // result [[ buffer(0) ]]
        let bufferCount = 3 * KPointAverageConstants.numCells // 3*25
        let bufferLength = MemoryLayout<UInt32>.size * bufferCount // 缓冲区长度
        let resultBuffer = self.device.makeBuffer(length: bufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 0)
        
        // params [[ buffer(1) ]]
        let paramBufferLength = MemoryLayout<UInt32>.size * 3;
        let options = MTLResourceOptions()
        let params = UnsafeMutableRawPointer.allocate(bytes: paramBufferLength, alignedTo: 1)
        // 该值存储为原始字节 从该指针的偏移量，以字节为单位
        params.storeBytes(of: UInt32(KPointAverageConstants.gridsAcross), toByteOffset: 0, as: UInt32.self)
        params.storeBytes(of: UInt32(width), toByteOffset: 4, as: UInt32.self)
        params.storeBytes(of: UInt32(height), toByteOffset: 8, as: UInt32.self)
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength, options: options)
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 1)
        // --------------------------------------------------------------------------------------------
        
        let gridSize : MTLSize = MTLSize(width: 8, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 32, height: 1, depth: 1) // 分组 Encoder 数据
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("完成图像纹理出错: \(buffer.error!.localizedDescription)")
            } else {
                
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: bufferCount))
//                print("processImageTexture \(results)")
                complete(results)
            }
        })
        commandBuffer.commit()
    }
    
    // 处理选择相片的纹理
    func processEntirePhotoTexture(texture: MTLTexture, gridSize: Int, numGridSpaces: Int, rows: Int, cols: Int, threadWidth: Int, complete: @escaping ([UInt32]) -> Void) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(self.photoPipelineState!)
        commandEncoder.setTexture(texture, at: 0)
        
        
        let paramBufferLength = MemoryLayout<UInt32>.size * 4;
        let options = MTLResourceOptions()
        let params = UnsafeMutableRawPointer.allocate(bytes: paramBufferLength, alignedTo: 1)
        params.storeBytes(of: UInt32(gridSize), as: UInt32.self)
        params.storeBytes(of: UInt32(rows), toByteOffset: 4, as: UInt32.self)
        params.storeBytes(of: UInt32(cols), toByteOffset: 8, as: UInt32.self)
        params.storeBytes(of: UInt32(KPointAverageConstants.gridsAcross), toByteOffset: 12, as: UInt32.self)
        // 使用 Metal 绘制顶点数据，我们需要将它放入缓冲区。缓冲区是被 CPU 和 GPU 共享的简单的无结构的内存块
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength, options: options)
        // 在绘制指令之前，我们使用预编译的管道状态设置渲染命令编码器并建立缓冲区，该缓冲区将作为顶点着色器的参数
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 0)
        
        
        let bufferCount = 3 * KPointAverageConstants.numCells * numGridSpaces
        let bufferLength = MemoryLayout<UInt32>.size * bufferCount
        let resultBuffer = self.device.makeBuffer(length: bufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 1)
        
        
        let gridSize : MTLSize = MTLSize(width: 32, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 64, height: 1, depth: 1) // 分组 Encoder 数据
        // 在 Compute encoder 中，为了提高计算的效率，每个图片都会分为一个小的单元送到 GPU 进行并行处理，分多少组和每个组的单元大小都是由 Encoder 来配置的。
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        // 通知编码器发布绘制指令完成
        commandEncoder.endEncoding()
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("There was an error finding the KPA of the reference photo: \(buffer.error!.localizedDescription)")
            } else {
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: bufferCount))
//                print("processEntirePhotoTexture \(results)")
                complete(results)
            }
        })
        // 编码结束之后，开始准备提交到 GPU
        commandBuffer.commit()
    }
    
    
    
    func processNearestAverages(refKPAs: [UInt32], otherKPAs: [UInt32], rows: Int, cols: Int, threadWidth: Int, complete: @escaping([UInt32]) -> Void) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(self.matchesPipelineState!)
        
        let refBuffer = self.device.makeBuffer(bytes: UnsafeRawPointer(refKPAs), length: MemoryLayout<UInt32>.size * refKPAs.count)
        commandEncoder.setBuffer(refBuffer, offset: 0, at: 0)
        
        let KPABuffer = self.device.makeBuffer(bytes: UnsafeRawPointer(otherKPAs), length: MemoryLayout<UInt32>.size * otherKPAs.count)
        commandEncoder.setBuffer(KPABuffer, offset: 0, at: 1)
        
        let resultBufferLength = MemoryLayout<UInt32>.size * rows * cols
        let resultBuffer = self.device.makeBuffer(length: resultBufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 2)
        
        let paramBufferLength = MemoryLayout<UInt32>.size * 4;
        let params = UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<UInt32>.size, alignedTo: 1)
        //        print("params: [\(refKPAs.count), \(otherKPAs.count)]")
        print("making params")
        params.storeBytes(of: UInt32(KPointAverageConstants.numCells), as: UInt32.self)
        params.storeBytes(of: UInt32(refKPAs.count), toByteOffset: 4, as: UInt32.self)
        params.storeBytes(of: UInt32(otherKPAs.count), toByteOffset: 8, as: UInt32.self)
        params.storeBytes(of: UInt32(cols), toByteOffset: 12, as: UInt32.self)
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength)
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 3)
        
        
        let gridSize : MTLSize = MTLSize(width: 8, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 64, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("There was an error completing the KPA matching: \(buffer.error!.localizedDescription)")
            } else {
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: rows * cols))
                complete(results)
            }
        })
        commandBuffer.commit()
    }
}
