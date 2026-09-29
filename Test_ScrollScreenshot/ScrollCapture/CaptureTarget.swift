import Cocoa

/// Area to capture, converted once into all the coordinate systems the capture needs.
///
/// - Cocoa (`NSScreen`, `NSWindow`): global, origin at the bottom-left of the primary display.
/// - ScreenCaptureKit `sourceRect`: display-local points, origin at the top-left of that display.
/// - Quartz events / cursor (`CGEvent`, `CGWarpMouseCursorPosition`): global, origin at the top-left of the primary display.
struct CaptureTarget {
  let displayID: CGDirectDisplayID
  let scale: CGFloat
  /// Rect for `SCStreamConfiguration.sourceRect`.
  let rectInDisplay: CGRect
  /// Centre of the area in global Quartz coordinates, where the cursor is moved and scroll events are posted.
  let centerInGlobalQuartz: CGPoint

  var pixelWidth: Int { Int((rectInDisplay.width * scale).rounded()) }
  var pixelHeight: Int { Int((rectInDisplay.height * scale).rounded()) }

  @MainActor
  init(screen: NSScreen, rectInScreenCoordinates rect: CGRect) {
    let rect = rect.integral
    let screenFrame = screen.frame
    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

    displayID = screen.displayID
    scale = screen.backingScaleFactor
    rectInDisplay = CGRect(x: rect.minX - screenFrame.minX,
                           y: screenFrame.maxY - rect.maxY,
                           width: rect.width,
                           height: rect.height)
    centerInGlobalQuartz = CGPoint(x: rect.midX,
                                   y: primaryScreenHeight - rect.midY)
  }
}
