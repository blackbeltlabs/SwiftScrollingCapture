import Foundation
import CoreGraphics

/// Collects the new rows of every frame and builds the final image once at the end
/// (instead of redrawing the whole stitched image on every step).
///
/// Output = first frame (with the sticky header) + new rows of every next frame + the rest of the last frame
/// (with the sticky footer), so sticky parts appear only once.
struct StripComposer {
  let width: Int

  /// Rows emitted so far (normalised RGBA, see `FrameBuffer`).
  private(set) var pixels: [UInt8] = []
  private(set) var height = 0

  /// Latest frame. Its rows starting from `emittedEnd` are not in `pixels` yet.
  private var lastFrame: FrameBuffer
  private var emittedEnd = 0

  init(firstFrame: FrameBuffer) {
    width = firstFrame.width
    lastFrame = firstFrame
  }

  /// `overlap` must describe how `next` relates to the frame passed before it.
  mutating func append(_ next: FrameBuffer, overlap: FrameOverlap) {
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

  func makeImage() throws -> CGImage {
    var result = self
    result.appendRows(of: lastFrame, emittedEnd..<lastFrame.height)
    return try FrameBuffer.makeImage(pixels: result.pixels, width: width, height: result.height)
  }

  private mutating func appendRows(of frame: FrameBuffer, _ range: Range<Int>) {
    guard !range.isEmpty else { return }
    pixels.append(contentsOf: frame.rowBytes(range))
    height += range.count
  }
}
