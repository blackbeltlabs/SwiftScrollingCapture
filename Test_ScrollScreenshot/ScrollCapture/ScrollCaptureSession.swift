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
    /// Same for the first step, as a share of the whole frame: sticky parts are not known yet, and if they take
    /// a big part of the frame a normal step would scroll past the whole scrolling area and lose the overlap.
    var firstScrollStepFraction: Double = 0.25
    var maxSteps = 200
    /// Height limit of the result, in pixels.
    var maxResultHeight = 40_000
    /// Delay between screenshots while waiting for scrolling / rendering to finish.
    var settleInterval: Duration = .milliseconds(60)
    /// After this the latest screenshot is used even if the screen is still changing (animations).
    var settleTimeout: Duration = .milliseconds(1500)
    /// How long an unchanged frame after a scroll is given to turn out to be a scroll that was not painted yet,
    /// before the scroll event is sent once more to tell a lost event from the end of the content. Counted from
    /// the first unchanged frame; frames that differ only in a small dynamic part do not shorten it.
    var latePaintTimeout: Duration = .milliseconds(700)
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
    /// On `.overlapLost`: the two frames that could not be matched, to see what changed between them.
    let lostOverlapFrames: (previous: CGImage, next: CGImage)?
  }

  private let target: CaptureTarget
  private let configuration: Configuration
  private let scroller = ScrollViewScroller()

  init(target: CaptureTarget, configuration: Configuration = .init()) {
    self.target = target
    self.configuration = configuration
  }

  /// Runs off the main thread. Cancelling the calling Task stops the capture and returns what was captured so far;
  /// before the first frame there is nothing to return, so it throws `CancellationError` instead.
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
    // Unchanged frames in a row at the current position, see `.identical` below.
    var unchangedFrames = 0
    var lostOverlapFrames: (previous: CGImage, next: CGImage)?

    loop: while steps < configuration.maxSteps {
      if Task.isCancelled {
        stopReason = .cancelled
        break
      }

      let stepFraction = knownStickyParts == nil ? configuration.firstScrollStepFraction : configuration.scrollStepFraction
      let stepInPoints = max(10, Int(Double(scrollingAreaHeight) * stepFraction / target.scale))
      // After one unchanged frame don't scroll again yet: the app may not have painted the scroll, and a second
      // event on top of a late one would move twice as far and lose the overlap. Wait for the paint instead.
      if unchangedFrames != 1 {
        scroller.scroll(byPoints: -Int32(stepInPoints), at: target.centerInGlobalQuartz)
        steps += 1
      }

      // After an unchanged frame, keep looking for `latePaintTimeout`: the app may paint the scroll late.
      // Only a frame that is not `.identical` counts as the paint. A caret, a clock or a fade changes the
      // frame too, but findOverlap still calls it `.identical`, so it neither ends the wait nor arms the
      // next scroll.
      let lookUntil = unchangedFrames == 1 ? ContinuousClock.now + configuration.latePaintTimeout : ContinuousClock.now
      var next: FrameBuffer
      var result: OverlapResult
      do {
        repeat {
          next = try await captureStableFrame(grabber, ignoredColumns: ignoredColumns)
          result = configuration.overlapFinder.findOverlap(previous: previous.rows,
                                                           next: next.rows,
                                                           expectedOffset: Int(CGFloat(stepInPoints) * target.scale),
                                                           knownStickyParts: knownStickyParts)
        } while result == .identical && ContinuousClock.now < lookUntil
      } catch is CancellationError {
        stopReason = .cancelled
        break
      }

      switch result {
      case .identical:
        // "Stable" only means two equal screenshots in a row, which a slow app also gives before it has painted
        // the scroll, and a scroll event can get lost. So the end is declared only after the frame stayed
        // `.identical` through `latePaintTimeout` without a scroll (see `lookUntil`) and then through one more
        // scroll event. At the real end this costs about a second.
        unchangedFrames += 1
        if unchangedFrames > 2 {
          stopReason = .reachedEnd
          break loop
        }
        continue

      case .notFound:
        stopReason = .overlapLost
        if let previousImage = try? previous.makeImage(), let nextImage = try? next.makeImage() {
          lostOverlapFrames = (previousImage, nextImage)
        }
        break loop

      case .overlap(let overlap):
        print("Step \(steps): offset \(overlap.offset) px, fixed top \(overlap.fixedTop) px, fixed bottom \(overlap.fixedBottom) px")
        unchangedFrames = 0
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
    return Result(image: try composer.makeImage(),
                  stopReason: stopReason,
                  steps: steps,
                  lostOverlapFrames: lostOverlapFrames)
  }

  /// Takes screenshots until two in a row show the same content, so the frame isn't taken in the middle of
  /// smooth scrolling or before the app re-rendered.
  private func captureStableFrame(_ grabber: ScreenFrameGrabber, ignoredColumns: Int) async throws -> FrameBuffer {
    var last = try await grabFrame(grabber, ignoredColumns: ignoredColumns)
    let deadline = ContinuousClock.now + configuration.settleTimeout

    while ContinuousClock.now < deadline {
      let current = try await grabFrame(grabber, ignoredColumns: ignoredColumns)
      if sameContent(current, last) {
        return current
      }
      last = current
    }

    return last
  }

  private func grabFrame(_ grabber: ScreenFrameGrabber, ignoredColumns: Int) async throws -> FrameBuffer {
    try await Task.sleep(for: configuration.settleInterval)
    let image = try await grabber.grab()
    return try FrameBuffer(cgImage: image, ignoredTrailingColumns: ignoredColumns)
  }

  /// Row-wise `isSimilar`, not `==`: a stationary Chromium view may rasterise the same content with another
  /// subpixel phase between two screenshots, which must not count as "still changing".
  private func sameContent(_ a: FrameBuffer, _ b: FrameBuffer) -> Bool {
    a.rows.count == b.rows.count && zip(a.rows, b.rows).allSatisfy { $0.isSimilar(to: $1) }
  }
}
