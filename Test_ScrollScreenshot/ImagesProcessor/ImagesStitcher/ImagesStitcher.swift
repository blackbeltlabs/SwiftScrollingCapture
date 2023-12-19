import Foundation
import Cocoa

private struct PixelsSize {
  let width: Int
  let height: Int
  
  var cgSize: CGSize {
    .init(width: width, height: height)
  }
}

struct ContextInput {
  let image1: CGImage
  let image2: CGImage
}

private struct CreatedContextData {
  let context: CGContext
  let canvasSize: PixelsSize
  let image1Size: PixelsSize
  let image2Size: PixelsSize
  let colorSpace: CGColorSpace
}

final class ImagesStitcher {
  enum Error: LocalizedError {
    case cantCreateCGImage
    case colorSpaceIsIncorrect
    case cantCreateContextToGenerateImage
    case cantRenderCGImage
  }

  func combineTwoImagesVertically(image1: NSImage, image2: NSImage) throws -> NSImage {
    guard let cgImage1 = image1.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let cgImage2 = image2.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      throw Error.cantCreateCGImage
    }
    
    let contextData = try createContext(input: .init(image1: cgImage1,
                                                 image2: cgImage2))
    let context = contextData.context
    context.draw(cgImage2, in: .init(origin: .zero,
                                     size: contextData.image2Size.cgSize))
    context.draw(cgImage1, in: .init(origin: .init(x: 0, y: contextData.image2Size.cgSize.height),
                                     size: contextData.image1Size.cgSize))
    
    guard let cgImage = context.makeImage() else {
      throw Error.cantRenderCGImage
    }
    
    return NSImage(cgImage: cgImage, size: .zero)
  }
  
  func combineTwoImagesVertically(image1: NSImage, image2: NSImage) async throws -> NSImage {
    let task = Task {
      return try combineTwoImagesVertically(image1: image1, image2: image2)
    }
    
    return try await task.value
  }
  
  private func createContext(input: ContextInput) throws -> CreatedContextData {
    
    guard let colorSpace = input.image1.colorSpace ?? NSColorSpace.deviceRGB.cgColorSpace else {
      throw Error.colorSpaceIsIncorrect
    }
    
    let image1Size = PixelsSize(width: input.image1.width,
                                height: input.image1.height)
    let image2Size = PixelsSize(width: input.image2.width,
                                height: input.image2.height)
    
    let canvasSize: PixelsSize = .init(width: max(image1Size.width, image2Size.width),
                                       height: image1Size.height + image2Size.height)
      
    let bitsPerComponent = 8 // RGBA with bitmapInfo
    let bytesPerRow = 0
    
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast
        
    // Some docs here
    // bytesPerRow should be zero. From official doc: Passing a value of 0 causes the value to be calculated automatically.
    // Also for bytes per row, https://stackoverflow.com/questions/6456788/in-this-cgbitmapcontextcreate-why-is-bytesperrow-0
    
    // About bits per component it should correspond to bitmapInfo constant
    // Read here -> https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB
    // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB
    guard let context = CGContext(data: nil,
                                  width: canvasSize.width,
                                  height: canvasSize.height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue) else {
      throw Error.cantCreateContextToGenerateImage
    }
    
    // image probably will be interpolated depending on its original size so need to set it to high as we want the best quality
    context.interpolationQuality = .high
  
    return .init(context: context,
                 canvasSize: canvasSize,
                 image1Size: image1Size,
                 image2Size: image2Size,
                 colorSpace: colorSpace)
  }
  
  func combineTwoImagesFirstRowApproach(image1: NSImage, image2: NSImage) throws -> NSImage {
    let imcProc = ImagesComparator()
    let imcCrop = ImagesCropper()
    // 1. Get the first row from the image 2
    let pixelRow1 = try imcProc.firstRow(for: image2)
    
    // 2. try to found the same row in the image 1
    guard let foundRow = try imcProc.findRow(pixelRow1, in: image1, startFromEnd: true) else {
      print("Not found")
      fatalError()
    }
    
    print("FOUND row = \(foundRow)")
    
    // 3.
    let cutYPosition = Int(image1.sizeInPixels.height) - foundRow + 1
    
    let size = image2.sizeInPixels
    
    let cutHeight = size.height - CGFloat(cutYPosition)
    
    // 4.
    
    let croppedImage = try imcCrop.crop(image2,
                                         rectInPixels: .init(x: 0,
                                        y: CGFloat(cutYPosition),
                                                             width: size.width,
                                             height: cutHeight))
    
    // 4. Stitch the main image with the previous one
    return try! combineTwoImagesVertically(image1: image1, image2: croppedImage)
  }
  
  
}

extension NSImage: @unchecked Sendable { }
