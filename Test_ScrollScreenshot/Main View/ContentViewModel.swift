import Foundation
import Cocoa

@MainActor
class ContentViewModel: ObservableObject {
    
  @Published var image: NSImage?
  var hotkey: HotKey?
    
  func takeScreenshot() async {
      do {
        let screen = NSScreen.main!
        guard let cgImage = try await ScreenshotTaker.takeFullScreenScreenshot(screen.displayID,
                                                                               scale: Int(screen.backingScaleFactor),
                                                                               rect: screen.frame) else { return }
            
        print("Size: \(cgImage.width) : \(cgImage.height)")
        image = NSImage(cgImage: cgImage, size: .zero)
      } catch let error {
        print(error.localizedDescription)
      }
    }
  
  func presentSelectionArea() {
    let wc = SelectionAssembler.assemble()
    wc.showWindow(self)
    
    wc.highlightInScreenCenter()
    
    hotkey = HotKey(keyCombo: .init(key: .return, modifiers: .init()))
    hotkey?.keyDownHandler = {
      print("Capture started")
    }
  }
  
}
