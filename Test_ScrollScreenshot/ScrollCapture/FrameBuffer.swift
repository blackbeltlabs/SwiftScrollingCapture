import Foundation
import CoreGraphics

/// Fingerprint of one pixel row, used to compare frames without comparing pixels again.
struct RowSignature: Equatable {
  let hash: UInt64
  /// All pixels in the row have the same colour (blank line, solid background).
  /// Such rows match almost anything, so they are not counted as evidence of an overlap.
  let isUniform: Bool
}

/// A frame normalised into one known pixel layout:
/// 8-bit RGBA, premultiplied alpha, sRGB, rows tightly packed (`bytesPerRow == width * 4`), row 0 is the top row.
///
/// ScreenCaptureKit returns BGRA images with padded rows, PNG decoding returns RGBA,
/// `CGContext.makeImage()` returns whatever the context used. Drawing every frame into the same
/// kind of buffer guarantees that equal content gives equal bytes.
struct FrameBuffer {
  static let bytesPerPixel = 4

  enum Error: LocalizedError {
    case cantCreateColorSpace
    case cantCreateContext
    case cantCreateImage
  }

  let width: Int
  let height: Int
  let pixels: [UInt8]
  let rows: [RowSignature]

  var bytesPerRow: Int { width * Self.bytesPerPixel }

  /// - Parameter ignoredTrailingColumns: columns at the right edge that are left out of the row signatures,
  ///   so an overlay scrollbar that appears / fades while scrolling does not break the matching.
  init(cgImage: CGImage, ignoredTrailingColumns: Int = 0) throws {
    let width = cgImage.width
    let height = cgImage.height

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw Error.cantCreateColorSpace
    }

    var pixels = [UInt8](repeating: 0, count: width * height * Self.bytesPerPixel)
    let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(data: buffer.baseAddress,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: width * Self.bytesPerPixel,
                                    space: colorSpace,
                                    bitmapInfo: Self.bitmapInfo.rawValue) else {
        return false
      }
      context.interpolationQuality = .none
      context.setBlendMode(.copy)
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }

    guard drawn else {
      throw Error.cantCreateContext
    }

    self.init(width: width, height: height, pixels: pixels, ignoredTrailingColumns: ignoredTrailingColumns)
  }

  /// `pixels` must already be in the normalised layout described above.
  init(width: Int, height: Int, pixels: [UInt8], ignoredTrailingColumns: Int = 0) {
    precondition(pixels.count == width * height * Self.bytesPerPixel, "Pixel buffer size doesn't match dimensions")
    self.width = width
    self.height = height
    self.pixels = pixels
    self.rows = Self.rowSignatures(pixels: pixels,
                                   width: width,
                                   height: height,
                                   comparedColumns: max(1, width - max(0, ignoredTrailingColumns)))
  }

  /// Bytes of the rows in `range` (top-down).
  func rowBytes(_ range: Range<Int>) -> ArraySlice<UInt8> {
    pixels[(range.lowerBound * bytesPerRow)..<(range.upperBound * bytesPerRow)]
  }

  func makeImage() throws -> CGImage {
    try Self.makeImage(pixels: pixels, width: width, height: height)
  }

  // MARK: - Helpers

  static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                                       | CGBitmapInfo.byteOrder32Big.rawValue)

  static func makeImage(pixels: [UInt8], width: Int, height: Int) throws -> CGImage {
    guard width > 0, height > 0,
          let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let provider = CGDataProvider(data: Data(pixels) as CFData),
          let image = CGImage(width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bitsPerPixel: 8 * bytesPerPixel,
                              bytesPerRow: width * bytesPerPixel,
                              space: colorSpace,
                              bitmapInfo: bitmapInfo,
                              provider: provider,
                              decode: nil,
                              shouldInterpolate: false,
                              intent: .defaultIntent) else {
      throw Error.cantCreateImage
    }
    return image
  }

  /// FNV-1a over 32-bit pixels + a uniform-row flag.
  private static func rowSignatures(pixels: [UInt8], width: Int, height: Int, comparedColumns: Int) -> [RowSignature] {
    let bytesPerRow = width * bytesPerPixel
    let offsetBasis: UInt64 = 0xcbf29ce484222325
    let prime: UInt64 = 0x100000001b3

    return pixels.withUnsafeBytes { raw in
      var signatures: [RowSignature] = []
      signatures.reserveCapacity(height)

      for row in 0..<height {
        let rowStart = row * bytesPerRow
        let firstPixel = raw.loadUnaligned(fromByteOffset: rowStart, as: UInt32.self)
        var hash = offsetBasis
        var isUniform = true

        for column in 0..<comparedColumns {
          let pixel = raw.loadUnaligned(fromByteOffset: rowStart + column * bytesPerPixel, as: UInt32.self)
          hash = (hash ^ UInt64(pixel)) &* prime
          if pixel != firstPixel {
            isUniform = false
          }
        }

        signatures.append(RowSignature(hash: hash, isUniform: isUniform))
      }

      return signatures
    }
  }
}
