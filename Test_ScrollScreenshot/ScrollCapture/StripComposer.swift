import Foundation
import CoreGraphics

/// Collects the new rows of every frame and builds the final image once at the end
/// (instead of redrawing the whole stitched image on every step).
///
/// Output = first frame (with the sticky header) + new rows of every next frame + the rest of the last frame
/// (with the sticky footer), so sticky parts appear only once.
struct StripComposer {
  let width: Int

  /// Rows emitted so far (normalised RGBA, see `FrameBuffer`). `Data`, not `[UInt8]`, so `makeImage()` can hand
  /// it to Core Graphics without copying the (possibly hundreds of MB) buffer.
  private(set) var pixels = Data()
  private(set) var height = 0

  /// Latest frame. Its rows starting from `emittedEnd` are not in `pixels` yet.
  private var lastFrame: FrameBuffer
  private var emittedEnd = 0
  private var isFinished = false

  init(firstFrame: FrameBuffer) {
    width = firstFrame.width
    lastFrame = firstFrame
  }

  /// `overlap` must describe how `next` relates to the frame passed before it.
  mutating func append(_ next: FrameBuffer, overlap: FrameOverlap) {
    precondition(!isFinished, "makeImage() was already called")
    precondition(next.width == width && next.height == lastFrame.height, "All frames must have the same size")

    // Emit the previous frame up to the start of its sticky footer.
    let scrollingRegionEnd = lastFrame.height - overlap.fixedBottom
    if emittedEnd < scrollingRegionEnd {
      appendRows(of: lastFrame, emittedEnd..<scrollingRegionEnd)
    }

    // The scrolling region moved up by `offset`, so everything emitted so far now ends at this row of the next frame.
    // (If an earlier step saw a shorter footer, a few rows below `scrollingRegionEnd` were already emitted
    // and get emitted again. That only happens when blank rows at the bottom were mistaken for a footer.)
    emittedEnd = scrollingRegionEnd - overlap.offset
    lastFrame = next
  }

  /// Height of the image `makeImage()` would return now.
  var totalHeight: Int {
    height + lastFrame.height - emittedEnd
  }

  /// Emits the rest of the last frame and builds the image. Mutating so the rows are appended in place: a copy of
  /// the composer would duplicate the whole buffer just to add the tail. No `append` is allowed after this.
  mutating func makeImage() throws -> CGImage {
    if !isFinished {
      appendRows(of: lastFrame, emittedEnd..<lastFrame.height)
      emittedEnd = lastFrame.height
      isFinished = true
    }
    return try FrameBuffer.makeImage(pixels: pixels, width: width, height: height)
  }

  private mutating func appendRows(of frame: FrameBuffer, _ range: Range<Int>) {
    guard !range.isEmpty else { return }
    frame.rowBytes(range).withUnsafeBytes { pixels.append(contentsOf: $0) }
    height += range.count
  }
}
