import Foundation
import CoreGraphics

/// Scrolls the view under the capture area step by step and stitches the frames into one tall image.
///
/// Loop: scroll a known distance → wait until the screen stops changing → find the offset against the previous
/// frame → keep only the new rows. Stops at the end of the content, on cancellation (Task.cancel()) or at a limit.
final class ScrollCaptureSession {
  struct Configuration {
    /// Scroll distance as a share of the scrolling area height. Smaller = more overlap = safer, but more steps.
    var scrollStepFraction: Double = 0.5
    var maxSteps = 200
    /// Height limit of the result, in pixels.
    var maxResultHeight = 40_000
    /// Delay between screenshots while waiting for scrolling / rendering to finish.
    var settleInterval: Duration = .milliseconds(60)
    /// After this the latest screenshot is used even if the screen is still changing (animations).
    var settleTimeout: Duration = .milliseconds(1500)
    /// Right edge excluded from matching, so an overlay scrollbar does not break it.
    var ignoredTrailingWidthInPoints: CGFloat = 16
    var overlapFinder = OverlapFinder()
  }

  enum StopReason: Equatable {
    case reachedEnd
    case cancelled
    case stepLimit
    case heightLimit
    /// Frames differ but don't overlap (scrolled too far, content changed). The result has everything before that.
    case overlapLost
  }

  struct Result {
    let image: CGImage
    let stopReason: StopReason
    let steps: Int
  }

  private let target: CaptureTarget
  private let configuration: Configuration
  private let scroller = ScrollViewScroller()

  init(target: CaptureTarget, configuration: Configuration = .init()) {
    self.target = target
    self.configuration = configuration
  }

  /// Runs off the main thread. Cancelling the calling Task stops the capture and returns what was captured so far.
  func run() async throws -> Result {
    let grabber = try await ScreenFrameGrabber(target: target)
    let ignoredColumns = Int((configuration.ignoredTrailingWidthInPoints * target.scale).rounded())

    // Scroll events go to the view under the cursor.
    scroller.moveCursor(to: target.centerInGlobalQuartz)

    var previous = try await captureStableFrame(grabber, ignoredColumns: ignoredColumns)
    var composer = StripComposer(firstFrame: previous)
    var scrollingAreaHeight = previous.height
    var knownStickyParts: StickyParts?
    var stopReason = StopReason.stepLimit
    var steps = 0

    loop: while steps < configuration.maxSteps {
      if Task.isCancelled {
        stopReason = .cancelled
        break
      }

      let stepInPoints = max(10, Int(Double(scrollingAreaHeight) * configuration.scrollStepFraction / target.scale))
      scroller.scroll(byPoints: -Int32(stepInPoints), at: target.centerInGlobalQuartz)
      steps += 1

      let next: FrameBuffer
      do {
        next = try await captureStableFrame(grabber, ignoredColumns: ignoredColumns)
      } catch is CancellationError {
        stopReason = .cancelled
        break
      }

      let result = configuration.overlapFinder.findOverlap(previous: previous.rows,
                                                           next: next.rows,
                                                           expectedOffset: Int(CGFloat(stepInPoints) * target.scale),
                                                           knownStickyParts: knownStickyParts)
      switch result {
      case .identical:
        stopReason = .reachedEnd
        break loop

      case .notFound:
        stopReason = .overlapLost
        break loop

      case .overlap(let overlap):
        print("Step \(steps): offset \(overlap.offset) px, fixed top \(overlap.fixedTop) px, fixed bottom \(overlap.fixedBottom) px")
        composer.append(next, overlap: overlap)
        scrollingAreaHeight = next.height - overlap.fixedTop - overlap.fixedBottom
        knownStickyParts = StickyParts(top: min(knownStickyParts?.top ?? .max, overlap.rowsInPlaceTop),
                                       bottom: min(knownStickyParts?.bottom ?? .max, overlap.rowsInPlaceBottom))
        previous = next
      }

      if composer.totalHeight >= configuration.maxResultHeight {
        stopReason = .heightLimit
        break
      }
    }

    print("Scroll capture finished: \(stopReason), steps: \(steps), height: \(composer.totalHeight) px")
    return Result(image: try composer.makeImage(), stopReason: stopReason, steps: steps)
  }

  /// Takes screenshots until two in a row are the same, so the frame isn't taken in the middle of
  /// smooth scrolling or before the app re-rendered.
  private func captureStableFrame(_ grabber: ScreenFrameGrabber, ignoredColumns: Int) async throws -> FrameBuffer {
    func grabFrame() async throws -> FrameBuffer {
      try await Task.sleep(for: configuration.settleInterval)
      let image = try await grabber.grab()
      return try FrameBuffer(cgImage: image, ignoredTrailingColumns: ignoredColumns)
    }

    var last = try await grabFrame()
    let deadline = ContinuousClock.now + configuration.settleTimeout

    while ContinuousClock.now < deadline {
      let current = try await grabFrame()
      if current.rows == last.rows {
        return current
      }
      last = current
    }

    return last
  }
}
