import Foundation
import Cocoa

enum ContextError: LocalizedError {
  case cantGetColorSpace
  case cantInstantiateContext
  case cantGetPixelsMatrix
  case pixelPointIsOutOfBounds
  
  case cantGetCGImage
  case cantGetCGImageDataProvider
}

struct PixelsMatrix {
  let width: Int
  let height: Int
  let pixelsBuffer: UnsafePointer<UInt8>
}

class ImagesComparator {
  static func compare(image1: NSImage, image2: NSImage) -> Bool {
    let time = Date().timeIntervalSinceReferenceDate
    guard let tiff1 = image1.tiffRepresentation,
          let tiff2 = image2.tiffRepresentation else {
      print("Can't instantiate tiff instances")
      return false
    }
    
    
    let result = tiff1 == tiff2
    
    let time2 = Date().timeIntervalSinceReferenceDate
    
    print("Diff = \(time2 - time)")
    
    return result
  }
  

  // https://gist.github.com/larsaugustin/af414f3637885f56c837b88c3fea1e6b
  func pixelsMatrix(nsImage: NSImage) throws -> PixelsMatrix {
      
    guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      throw ContextError.cantGetCGImage
    }
    guard let dataProvider = cgImage.dataProvider else {
      throw ContextError.cantGetCGImageDataProvider
    }
    
    let buffer: UnsafePointer<UInt8> = CFDataGetBytePtr(dataProvider.data)
    
    return .init(width: cgImage.width,
                 height: cgImage.height,
                 pixelsBuffer: buffer)
  }
  
  private func pixel(from matrix: PixelsMatrix, at point: PixelPoint) throws -> Pixel {
    guard point.x < matrix.width && point.y < matrix.height else {
      throw ContextError.pixelPointIsOutOfBounds
    }
    
    let buffer = matrix.pixelsBuffer
    let bytesPerPixel = 4
    let offset = point.y * matrix.width * bytesPerPixel + point.x * bytesPerPixel
    return .init(r: buffer.advanced(by: offset + 0).pointee,
                 g: buffer.advanced(by: offset + 1).pointee,
                 b: buffer.advanced(by: offset + 2).pointee,
                 a: buffer.advanced(by: offset + 3).pointee)
  }
  
  
  func pixel(from nsImage: NSImage, at point: PixelPoint) throws -> Pixel {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: nsImage)
    return try pixel(from: pixelsMatrix, at: point)
  }
  
  func pixelsRow(from nsImage: NSImage, row: Int) throws -> [Pixel] {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: nsImage)
    return try pixelsRow(from: pixelsMatrix, row: row)
    
  }
  
  func pixelsRow(from matrix: PixelsMatrix, row: Int) throws -> [Pixel] {
    var array: [Pixel] = []
    
    for i in 0..<matrix.width {
      let nextPixel = try pixel(from: matrix, at: .init(x: i, y: row))
      array.append(nextPixel)
    }
    
    return array
  }
  
  func findRow( _ rowToFind: [Pixel], in image: NSImage, startFromEnd: Bool = false) throws -> Int?  {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: image)
    return try findRow(rowToFind, in: pixelsMatrix, startFromEnd: startFromEnd)
  }
  
  func findRow(_ rowToFind: [Pixel], in matrix: PixelsMatrix, startFromEnd: Bool = false) throws -> Int? {
    guard rowToFind.count == matrix.width else {
      return nil
    }
    
    let start: Int = startFromEnd ? matrix.height - 1 : 0
    let end: Int = startFromEnd ? -1 : matrix.height
    
    let step: Int = startFromEnd ? -1 : 1
    
    for i in stride(from: start, to: end, by: step) {
          
      let nextRow = try pixelsRow(from: matrix, row: i)
      if nextRow == rowToFind {
        return i
      }
    }
    
    return nil
  }
    
  func latestRow(for nsImage: NSImage) throws -> [Pixel] {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: nsImage)
    return try pixelsRow(from: pixelsMatrix, row: pixelsMatrix.height - 1)
  }
  
  func firstRow(for nsImage: NSImage) throws -> [Pixel] {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: nsImage)
    return try pixelsRow(from: pixelsMatrix, row: 0)
  }
  
  func allPixels(from image: NSImage) throws -> [[Pixel]]  {
    let pixelsMatrix = try self.pixelsMatrix(nsImage: image)
    return getAllPixels(for: pixelsMatrix)
  }
  
  private func getAllPixels(for matrix: PixelsMatrix) -> [[Pixel]] {
    var array = [[Pixel]](repeating: .init(repeating: .zero, count: matrix.width),
                          count: matrix.height)
    
    var data = matrix.pixelsBuffer
    
    for y in 0..<matrix.height {
      for x in 0..<matrix.width {
        var r, g, b, a: UInt8
        
        r = data.pointee
        data = data.advanced(by: 1)
        g = data.pointee
        data = data.advanced(by: 1)
        b = data.pointee
        data = data.advanced(by: 1)
        a = data.pointee

        data = data.advanced(by: 1)
  
        array[y][x] = Pixel(r: r, g: g, b: b, a: a)
      }
    }
    
    return array
  }
  
  
  
  func allColors(bitmap: CGContext) -> [Pixel: Int] {
    let width = bitmap.width
    let height = bitmap.height
    
    guard let pixelData = bitmap.data else {
      return [:]
    }
    
    var data = pixelData.bindMemory(to: UInt8.self,
                                    capacity: width * height)
    
    
    var r, g, b, a: UInt8
    
    var pixelsDict: [Pixel: Int] = [:]
      
    for _ in 0..<height {
      for _ in 0..<width {
        // get red, green, blue colors and alpha accordingly
        r = data.pointee
        data = data.advanced(by: 1)
        g = data.pointee
        data = data.advanced(by: 1)
        b = data.pointee
        data = data.advanced(by: 1)
        a = data.pointee

        data = data.advanced(by: 1)
        
        // generate new Pixel instance
        let pixel = Pixel(r: r, g: g, b: b, a: a)
        print(pixel)

      }
    }
       
    return pixelsDict
  }
  
  func compareByPixels(image1: NSImage, image2: NSImage) -> Bool {
    let time = Date().timeIntervalSinceReferenceDate
    do {
      let context = try drawImageIntoContext(nsImage: image1)
      let allColors = allColors(bitmap: context.cgContext)
    } catch let error {
      print(error.localizedDescription)
    }
  
    let time2 = Date().timeIntervalSinceReferenceDate
    print("Diff = \(time2 - time)")
    return true
  }
  
  func drawImageIntoContext(nsImage: NSImage, title: String = "Context") throws -> NSGraphicsContext {
    let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
    print("\(title): Image size = \(imageSize)")
    
    let imageRect = NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
    
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw ContextError.cantGetColorSpace
    }
    
    guard let ctx: CGContext = CGContext(data: nil,
                                         width: Int(imageSize.width),
                                         height: Int(imageSize.height),
                                         bitsPerComponent: 8,
                                         bytesPerRow: 0,
                                         space: colorSpace,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      throw ContextError.cantInstantiateContext
    }
  
    print("\(title): CTX width = \(ctx.width), height = \(ctx.height)")
    
    let gctx = NSGraphicsContext(cgContext: ctx, flipped: false)
    
     // Make our bitmap context current and render the NSImage into it
    NSGraphicsContext.current = gctx
    nsImage.draw(in: imageRect)
    
    return gctx
  }
}


// MARK: - CGContext approach (deprecated)
extension ImagesComparator {
  func pixelsMatrix(bitmap: CGContext) throws -> PixelsMatrix {
    guard let pixelData = bitmap.data else {
      throw ContextError.cantGetPixelsMatrix
    }
    
    let width = bitmap.width
    let height = bitmap.height
    
    let pixelsBuffer = pixelData.bindMemory(to: UInt8.self,
                                            capacity: width * height)
    
    return .init(width: width,
                 height: height,
                 pixelsBuffer: pixelsBuffer)
  }
  
}


extension Array where Element == [Pixel] {
  var description: String {
    var fullString = ""
    for (index, element) in self.enumerated() {
      let element = "\(index) : \(element)"
      fullString.append(element)
      fullString.append("\n")
    }
    
    return fullString
  }
}


extension NSImage {
  var sizeInPixels: CGSize {
    let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    
    return .init(width: cgImage.width,
                 height: cgImage.height)
  }
}
