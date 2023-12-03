import Foundation
import Cocoa

final class ImagesCropper {
    
  enum Error: LocalizedError {
    case cantGetCGImageFromNSImage
    case cantCropCGImage
  }
    
    
  func crop(_ nsImage: NSImage, rectInPixels: CGRect) throws -> NSImage {
    guard let cgImage = nsImage.cgImage(forProposedRect: nil,
                                        context: nil,
                                        hints: nil) else {
      throw Error.cantGetCGImageFromNSImage
    }
    
    guard let croppedImage = cgImage.cropping(to: rectInPixels) else {
      throw Error.cantCropCGImage
    }

    return NSImage(cgImage: croppedImage,
                   size: .zero)
  }
}
