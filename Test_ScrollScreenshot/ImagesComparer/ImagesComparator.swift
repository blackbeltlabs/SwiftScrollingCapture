import Foundation
import Cocoa

class ImagesComparator {
  static func compare(image1: NSImage, image2: NSImage) -> Bool {
    guard let tiff1 = image1.tiffRepresentation,
          let tiff2 = image2.tiffRepresentation else {
      print("Can't instantiate tiff instances")
      return false
    }
    
    return tiff1 == tiff2
  }
}
