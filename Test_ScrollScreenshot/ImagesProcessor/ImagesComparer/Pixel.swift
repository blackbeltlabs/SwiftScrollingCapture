import Foundation
import Cocoa

struct PixelPoint {
  let x: Int
  let y: Int
}

struct Pixel: Hashable, Equatable, CustomStringConvertible {
  let r: Int
  let g: Int
  let b: Int
  let a: Int

  init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
      self.r = Int(r)
      self.g = Int(g)
      self.b = Int(b)
      self.a = Int(a)
  }
  
  var description: String {
    String(format:"%02X%02X%02X", r, g, b)
  }

//  var color: NSColor {
//    NSColor(red: CGFloat(r / 255.0),
//            green: CGFloat(g / 255.0),
//            blue: CGFloat(b / 255.0),
//            alpha: CGFloat(a / 255.0))
//  }
//  
//  var solidColor: NSColor {
//    NSColor(red: CGFloat(r / 255.0),
//            green: CGFloat(g / 255.0),
//            blue: CGFloat(b / 255.0),
//            alpha: 1.0)
//  }

//  var description: String {
//    "RGBA(\(r), \(g), \(b), \(a))"
//  }
  
  static var zero: Self {
    .init(r: 0, g: 0, b: 0, a: 0)
  }
  
  // do not take alpha into the consideration for the purpose of this app
  func hash(into hasher: inout Hasher) {
    hasher.combine(r)
    hasher.combine(g)
    hasher.combine(b)
  }
}
