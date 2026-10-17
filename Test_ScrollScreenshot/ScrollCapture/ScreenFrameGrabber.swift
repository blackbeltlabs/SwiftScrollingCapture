import Foundation
import ScreenCaptureKit

/// Takes screenshots of one area. The display, filter and configuration are prepared once,
/// because `SCShareableContent` is slow to query and the capture loop takes many screenshots.
final class ScreenFrameGrabber {
  private let filter: SCContentFilter
  private let configuration: SCStreamConfiguration

  init(target: CaptureTarget) async throws {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

    guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
      throw RecordingError.cantFindDisplayWithID
    }

    // Leave out our own windows (selection frame, main window) so they never end up in the result.
    let ownProcessID = ProcessInfo.processInfo.processIdentifier
    let ownApplications = content.applications.filter { $0.processID == ownProcessID }
    filter = SCContentFilter(display: display,
                             excludingApplications: ownApplications,
                             exceptingWindows: [])

    let configuration = SCStreamConfiguration()
    configuration.sourceRect = target.rectInDisplay
    // Size is in pixels: without the scale factor the image is scaled and gets blurry.
    configuration.width = target.pixelWidth
    configuration.height = target.pixelHeight
    // The cursor stays over the scrolled view the whole time. If it's captured, it breaks the row matching.
    configuration.showsCursor = false
    configuration.colorSpaceName = CGColorSpace.sRGB
    self.configuration = configuration
  }

  func grab() async throws -> CGImage {
    try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
  }
}
