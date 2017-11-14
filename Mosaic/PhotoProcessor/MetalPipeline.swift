//
//  MetalPipeline.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/13.
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
    let NinePointAverage : MTLFunction
    let PhotoNinePointAverage : MTLFunction
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
        self.NinePointAverage = self.library.makeFunction(name: "findNinePointAverage")!
        //参考照片KPA
        self.PhotoNinePointAverage = self.library.makeFunction(name: "findPhotoNinePointAverage")!
        //匹配功能
        self.FindNearestMatches = self.library.makeFunction(name: "findNearestMatches")!
        // 创建设置了函数和像素格式的管道描述器
        do {
            self.pipelineState = try self.device.makeComputePipelineState(function: self.NinePointAverage)
            self.photoPipelineState = try self.device.makeComputePipelineState(function: self.PhotoNinePointAverage)
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
    
    // 获取原始纹理
    private func getImageTextureRaw(image: CGImage) -> MTLTexture {
        let rawData = calloc(image.height * image.width * 4, MemoryLayout<UInt8>.size)
        let bytesPerRow = 4 * image.width // 每行的字节数
        // 选择: 图像的透明度 和信息
        let options = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        // 石英2D绘图环境
        let context = CGContext(
            data: rawData,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: options
        )
        
//        draw方法绘制的图像是上下颠倒的
        context?.draw(image, in : CGRect(x:0, y: 0, width: image.width, height: image.height))
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: image.width,
            height: image.height,
            mipmapped: true
        )
        // 纹理着色器
        let texture : MTLTexture = self.device.makeTexture(descriptor: textureDescriptor)
        texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height),
                        mipmapLevel: 0,
                        slice: 0,
                        withBytes: rawData!,
                        bytesPerRow: bytesPerRow,
                        bytesPerImage: bytesPerRow * image.height)
        free(rawData)
        return texture
    }
    
    // 发布绘制图像指令
//    先构造 MTLCommandBuffer ，再配置 CommandEncoder ，包括配置资源文件，渲染管线等，再通过 CommandEncoder 进行编码，最后才能提交到队列中去
    func processImageTexture(texture: MTLTexture, width: Int, height: Int, threadWidth: Int, complete : @escaping ([UInt32]) -> Void) {
        let commandBuffer = self.commandQueue.makeCommandBuffer() // 命令缓冲区
        let commandEncoder = commandBuffer.makeComputeCommandEncoder() // 命令编码器
// 在绘制指令之前，我们使用预编译的管道状态设置渲染命令编码器并建立缓冲区，该缓冲区将作为顶点着色器的参数-----------------
        commandEncoder.setComputePipelineState(self.pipelineState!)
        commandEncoder.setTexture(texture, at: 0)
        
        // 为了真正的绘制几何图形，我们告诉 Metal 要绘制的形状 (三角形) 和缓冲区中顶点的数量
        let bufferCount = 3 * TenPointAverageConstants.numCells // 3*25
        let bufferLength = MemoryLayout<UInt32>.size * bufferCount // 缓冲区长度
        let resultBuffer = self.device.makeBuffer(length: bufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 0)
        
        let paramBufferLength = MemoryLayout<UInt32>.size * 3;
        let options = MTLResourceOptions()
        let params = UnsafeMutableRawPointer.allocate(bytes: paramBufferLength, alignedTo: 1)
        params.storeBytes(of: UInt32(TenPointAverageConstants.gridsAcross), toByteOffset: 0, as: UInt32.self)
        params.storeBytes(of: UInt32(width), toByteOffset: 4, as: UInt32.self)
        params.storeBytes(of: UInt32(height), toByteOffset: 8, as: UInt32.self)
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength, options: options)
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 1)
// --------------------------------------------------------------------------------------------
        
        let gridSize : MTLSize = MTLSize(width: 8, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 32, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("There was an error completing an image texture: \(buffer.error!.localizedDescription)")
            } else {
                
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: bufferCount))
                print("processImageTexture \(results)")
                complete(results)
            }
        })
        commandBuffer.commit()
    }
    
    // 处理所有相片的纹理
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
        params.storeBytes(of: UInt32(TenPointAverageConstants.gridsAcross), toByteOffset: 12, as: UInt32.self)
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength, options: options)
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 0)
        
        
        let bufferCount = 3 * TenPointAverageConstants.numCells * numGridSpaces
        let bufferLength = MemoryLayout<UInt32>.size * bufferCount
        let resultBuffer = self.device.makeBuffer(length: bufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 1)
        
        
        let gridSize : MTLSize = MTLSize(width: 32, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 64, height: 1, depth: 1)
        
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("There was an error finding the TPA of the reference photo: \(buffer.error!.localizedDescription)")
            } else {
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: bufferCount))
                print("processEntirePhotoTexture \(results)")
                complete(results)
            }
        })
        commandBuffer.commit()
    }
    
    
    
    func processNearestAverages(refTPAs: [UInt32], otherTPAs: [UInt32], rows: Int, cols: Int, threadWidth: Int, complete: @escaping([UInt32]) -> Void) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(self.matchesPipelineState!)
        
        let refBuffer = self.device.makeBuffer(bytes: UnsafeRawPointer(refTPAs), length: MemoryLayout<UInt32>.size * refTPAs.count)
        commandEncoder.setBuffer(refBuffer, offset: 0, at: 0)
        
        let tpaBuffer = self.device.makeBuffer(bytes: UnsafeRawPointer(otherTPAs), length: MemoryLayout<UInt32>.size * otherTPAs.count)
        commandEncoder.setBuffer(tpaBuffer, offset: 0, at: 1)
        
        let resultBufferLength = MemoryLayout<UInt32>.size * rows * cols
        let resultBuffer = self.device.makeBuffer(length: resultBufferLength)
        commandEncoder.setBuffer(resultBuffer, offset: 0, at: 2)
        
        let paramBufferLength = MemoryLayout<UInt32>.size * 4;
        let params = UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<UInt32>.size, alignedTo: 1)
        //        print("params: [\(refTPAs.count), \(otherTPAs.count)]")
        print("making params")
        params.storeBytes(of: UInt32(TenPointAverageConstants.numCells), as: UInt32.self)
        params.storeBytes(of: UInt32(refTPAs.count), toByteOffset: 4, as: UInt32.self)
        params.storeBytes(of: UInt32(otherTPAs.count), toByteOffset: 8, as: UInt32.self)
        params.storeBytes(of: UInt32(cols), toByteOffset: 12, as: UInt32.self)
        let paramBuffer = self.device.makeBuffer(bytes: params, length: paramBufferLength)
        commandEncoder.setBuffer(paramBuffer, offset: 0, at: 3)
        
        
        let gridSize : MTLSize = MTLSize(width: 8, height: 1, depth: 1)
        let threadGroupSize : MTLSize = MTLSize(width: 64, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler({(buffer) -> Void in
            if (buffer.error != nil) {
                print("There was an error completing the TPA matching: \(buffer.error!.localizedDescription)")
            } else {
                let results : [UInt32] = Array(UnsafeBufferPointer(start: resultBuffer.contents().assumingMemoryBound(to: UInt32.self), count: rows * cols))
                complete(results)
            }
        })
        commandBuffer.commit()
    }
}
