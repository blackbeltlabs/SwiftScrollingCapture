import Foundation
import Cocoa

class SelectionWindowController: NSWindowController, NSWindowDelegate {
    // MARK: - Public API
  func highlight(frame: CGRect, animate: Bool = false) {
    if animate {
        NSAnimationContext.current.duration = 0.1
      }
      let target = animate ? window?.animator() : window
      target?.setFrame(frame, display: false)
    }
  
  func highlightInScreenCenter(center: CGPoint, size: CGSize = .init(width: 500, height: 500)) -> CGRect {
   
    
    let frame = CGRect(x: center.x - size.width / 2.0,
                       y: center.y - size.height / 2.0,
                       width: size.width,
                       height: size.height)
    highlight(frame: frame)
    return frame
  }
}
