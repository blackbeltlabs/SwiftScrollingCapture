import Cocoa

final class SelectionAssembler {
    private init() {
    }
  static func assemble() -> SelectionWindowController {
    let window = assembleWindow()
    let windowController = SelectionWindowController(window: window)
    windowController.contentViewController = HighlightViewController()
    return windowController
  }
  
  private static func assembleWindow() -> NSWindow {
    let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
    window.isOpaque = false
    window.level = .screenSaver
    window.backgroundColor = NSColor.clear
    window.alphaValue = 0.5
    window.ignoresMouseEvents = true
    return window
  }
}
