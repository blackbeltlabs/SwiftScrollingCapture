import Foundation
import Cocoa

@MainActor
class ContentViewModel: ObservableObject {
  
  let accessibilityManager = AccessibilityPermissionsManager()
    
  @Published var image: NSImage?
  var hotkey: HotKey?
  let scroller = ScrollViewScroller()
  
  private var selectionRect: CGRect?
  private var screen: NSScreen?
  
  
  let stitcher = ImagesStitcher()
    
  func takeScreenshot() async {
    do {
      guard let screen, let selectionRect else { return }
      let cgImage = try await ScreenshotTaker.takeFullScreenScreenshot(screen.displayID,
                                                                       scale: Int(screen.backingScaleFactor),
                                                                       rect: selectionRect.insetBy(dx: 2, dy: 2))
            
      print("Size: \(cgImage.width) : \(cgImage.height)")
      let newImage = NSImage(cgImage: cgImage, size: .zero)
        
      if let image {
        let result = compare(image1: image, image2: newImage)
        print("Comparation result = \(result)")
      }
        
      image = newImage
    } catch let error {
      print(error.localizedDescription)
    }
  }
  
  func takeScreenshotFromSelectionRect() async throws -> NSImage {
    guard let screen, let selectionRect else { fatalError() }
    let cgImage = try await ScreenshotTaker.takeFullScreenScreenshot(screen.displayID,
                                                                     scale: Int(screen.backingScaleFactor),
                                                                     rect: selectionRect.insetBy(dx: 2, dy: 2))
    return NSImage(cgImage: cgImage, size: .zero)
  }
  
  func presentSelectionArea() {
    let wc = SelectionAssembler.assemble()
    wc.showWindow(self)
    
    let screen = NSScreen.main!
    let screenFrame = screen.frame
    let center = CGPoint(x: screenFrame.width / 2,
                         y: screenFrame.height / 2)
    
    self.screen = screen
    selectionRect = wc.highlightInScreenCenter(center: center)
    
    
    
    hotkey = HotKey(keyCombo: .init(key: .return, modifiers: .init()))
    hotkey?.keyDownHandler = {
      Task {
        try await self.scrollToBottom(from: center)
      }
      print("Capture started")
    }
  }
  
  func compare(image1: NSImage, image2: NSImage) -> Bool {
    guard let tiff1 = image1.tiffRepresentation,
          let tiff2 = image2.tiffRepresentation else {
      print("Can't instantiate tiff instances")
      return false
    }
    
    return tiff1 == tiff2
  }
  
  @MainActor
  func scrollToBottom(from point: CGPoint) async throws {
    var previous: NSImage?
    var next: NSImage?
    
    var finalImage: NSImage?
    
    previous = try await takeScreenshotFromSelectionRect()
    
    print("SCROLLING STARTED")
    
    while (true) {
      self.scroller.scrollMouse(onPoint: point, xLines: 0, yLines: -5)
      
      next = try await takeScreenshotFromSelectionRect()
      guard let prev = previous, let next else {
        fatalError()
      }
      if ImagesComparator.compare(image1: prev, image2: next) {
        break
      }
      if let finImage = finalImage {
        finalImage = try await stitcher.combineTwoImagesVertically(image1: finImage, image2: next)
      } else {
        finalImage = try await stitcher.combineTwoImagesVertically(image1: prev, image2: next)
      }
      
      previous = next
    }
    print("SCROLLING COMPLETED")
    
    if let finalImage {
      let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.appendingPathComponent("test_full.png",
                                                                                                                    conformingTo: .png)
      
      let cgImage = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
      let written = CGImageWriter.writeCGImageAsPng(cgImage, to: url)
    }
    
    self.image = finalImage
  }
  
  func requestAccessibilityPressed() {
    guard !accessibilityManager.accesibilityEnabled else { return }
    accessibilityManager.requestAccessibility()
  }
  
  func mergeTwoImagesPressed() {
    let image1 = getImage(with: "test0", resource: "png")
    let image2 = getImage(with: "test1", resource: "png")
    
      
    let resultImage = try! stitcher.combineTwoImagesVertically(image1: image1, image2: image2)
    
    
    image = resultImage
    
    guard let cgImage = resultImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

    let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.appendingPathComponent("test.png",
                                                                                                                  conformingTo: .png)
    
    let written = CGImageWriter.writeCGImageAsPng(cgImage, to: url)
    
  }
  
  func getImage(with name: String, resource: String) -> NSImage {
    let url = Bundle.main.url(forResource: name, withExtension: resource)!
    let data = try! Data(contentsOf: url)
    return NSImage(data: data)!
  }
  

  func compareTwoImagesPressed() {
    let comparator = ImagesComparator()
    let image1 = getImage(with: "test0", resource: "png")
    let image2 = getImage(with: "test1", resource: "png")
    
    let areEqual = comparator.compareByPixels(image1: image1, image2: image2)
    
    print("Are equal = \(areEqual)")
  }
  
}

