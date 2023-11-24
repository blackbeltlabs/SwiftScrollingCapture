import Foundation
import Cocoa

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
}
