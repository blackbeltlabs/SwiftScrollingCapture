import AppKit

class HighlightViewController: NSViewController {
  var hotkey: HotKey?
  override func loadView() {
    self.view = NSView()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.borderWidth = 2.0
    view.layer?.cornerRadius = 4.0
    view.layer?.borderColor = NSColor.green.cgColor
    
   
    
  }
  
}
