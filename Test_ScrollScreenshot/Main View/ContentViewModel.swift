import Foundation
import Cocoa

@MainActor
class ContentViewModel: ObservableObject {
  
  let accessibilityManager = AccessibilityPermissionsManager()
    
  @Published var image: NSImage?
  @Published var status = ""

  private var startHotKey: HotKey?
  private var cancelHotKey: HotKey?
  private var selectionWindowController: SelectionWindowController?
  private var captureTask: Task<Void, Never>?

  private var selectionRect: CGRect?
  private var screen: NSScreen?
  
  
  let stitcher = ImagesStitcher()
  let screenshotTaker = ScreenshotTaker()
    
  func takeScreenshot() async {
    do {
      guard let screen, let selectionRect else { return }
      let cgImage = try await ScreenshotTaker.takeScreenshot(screen.displayID,
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
    let cgImage = try await ScreenshotTaker.takeScreenshot(screen.displayID,
                                                           scale: Int(screen.backingScaleFactor),
                                                           rect: selectionRect.insetBy(dx: 5, dy: 5))
    return NSImage(cgImage: cgImage, size: .zero)
  }
  
  func presentSelectionArea() {
    guard captureTask == nil, let screen = NSScreen.main else { return }

    selectionWindowController?.close()
    let wc = SelectionAssembler.assemble()
    wc.showWindow(self)

    let center = CGPoint(x: screen.frame.midX,
                         y: screen.frame.midY)

    self.screen = screen
    selectionRect = wc.highlightInScreenCenter(center: center)
    selectionWindowController = wc

    startHotKey = HotKey(keyCombo: .init(key: .return, modifiers: .init()))
    startHotKey?.keyDownHandler = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.startScrollCapture()
      }
    }

    status = "Put a scrollable view under the green frame and press Return. Press Esc to stop."
  }

  func startScrollCapture() {
    guard captureTask == nil, let screen, let selectionRect else { return }

    guard accessibilityManager.accesibilityEnabled else {
      status = "Accessibility permission is needed to scroll other apps. Grant it and press Return again."
      accessibilityManager.requestAccessibility()
      return
    }

    // Stop taking Return away from other apps, Esc stops the capture instead.
    startHotKey = nil
    cancelHotKey = HotKey(keyCombo: .init(key: .escape, modifiers: .init()))
    cancelHotKey?.keyDownHandler = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.captureTask?.cancel()
      }
    }

    // The frame's border is drawn inside the selection rect.
    let target = CaptureTarget(screen: screen, rectInScreenCoordinates: selectionRect.insetBy(dx: 3, dy: 3))
    let session = ScrollCaptureSession(target: target)

    // Our windows are left out of the screenshots, but scroll events would still go to them
    // if they were under the cursor, so hide the app while capturing.
    NSApp.hide(nil)
    status = "Capturing..."

    captureTask = Task {
      do {
        let result = try await session.run()
        let url = saveToDesktop(result.image, fileName: "scroll_capture.png")
        image = NSImage(cgImage: result.image, size: .zero)
        status = "Done: \(result.stopReason), \(result.steps) steps, \(result.image.width)x\(result.image.height) px. Saved to \(url?.path ?? "nowhere (saving failed)")"
      } catch {
        status = "Capture failed: \(error.localizedDescription)"
      }
      finishScrollCapture()
    }
  }

  private func finishScrollCapture() {
    cancelHotKey = nil
    captureTask = nil
    selectionWindowController?.close()
    selectionWindowController = nil
    NSApp.unhide(nil)
  }

  private func saveToDesktop(_ cgImage: CGImage, fileName: String) -> URL? {
    guard let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else { return nil }
    let url = desktop.appendingPathComponent(fileName, conformingTo: .png)
    return CGImageWriter.writeCGImageAsPng(cgImage, to: url) ? url : nil
  }

  /// Runs the overlap search and stitching on the bundled scroll0.png / scroll1.png, no screen capture needed.
  /// These two images were captured with the mouse cursor visible, so a small block differs inside the overlap,
  /// which is within the default tolerance.
  func offlineCheckPressed() {
    let expectedOffset = 560

    do {
      guard let cgImage1 = getImage(with: "scroll0", resource: "png").cgImage(forProposedRect: nil, context: nil, hints: nil),
            let cgImage2 = getImage(with: "scroll1", resource: "png").cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        status = "Offline check: can't load the test images"
        return
      }

      let frame1 = try FrameBuffer(cgImage: cgImage1)
      let frame2 = try FrameBuffer(cgImage: cgImage2)

      let result = OverlapFinder().findOverlap(previous: frame1.rows, next: frame2.rows)
      guard case .overlap(let overlap) = result else {
        status = "Offline check FAILED: \(result)"
        return
      }

      var composer = StripComposer(firstFrame: frame1)
      composer.append(frame2, overlap: overlap)
      let stitched = try composer.makeImage()
      image = NSImage(cgImage: stitched, size: .zero)

      let verdict = overlap.offset == expectedOffset ? "OK" : "FAILED"
      status = "Offline check \(verdict): offset \(overlap.offset) px (expected \(expectedOffset)), result height \(stitched.height) px (expected \(frame1.height + expectedOffset))"
    } catch {
      status = "Offline check failed: \(error.localizedDescription)"
    }
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
    
    let areEqual = try! comparator.compareByPixels(image1: image1, image2: image2)
    
    print("Are equal = \(areEqual)")
  }
  
}

