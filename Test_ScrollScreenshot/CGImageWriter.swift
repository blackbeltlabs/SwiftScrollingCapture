import Cocoa
import Foundation
import UniformTypeIdentifiers

final class CGImageWriter {
  static func writeCGImageAsPng(_ cgImage: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
      return false
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    return CGImageDestinationFinalize(destination)
  }
}
