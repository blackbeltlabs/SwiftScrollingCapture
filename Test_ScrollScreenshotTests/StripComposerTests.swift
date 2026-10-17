import XCTest
@testable import Test_ScrollScreenshot

final class StripComposerTests: XCTestCase {
  private let width = 2

  /// A frame whose row `r` is filled with the byte `rows[r]`.
  private func frame(rows: [UInt8]) -> FrameBuffer {
    FrameBuffer(width: width, height: rows.count, pixels: bytes(rows: rows))
  }

  private func bytes(rows: [UInt8]) -> [UInt8] {
    rows.flatMap { Array(repeating: $0, count: width * FrameBuffer.bytesPerPixel) }
  }

  private func overlap(offset: Int, fixedBottom: Int = 0) -> FrameOverlap {
    FrameOverlap(fixedTop: 0, fixedBottom: fixedBottom, offset: offset, rowsInPlaceTop: 0, rowsInPlaceBottom: fixedBottom)
  }

  func testOnlyNewRowsAreAppended() throws {
    var composer = StripComposer(firstFrame: frame(rows: [1, 2, 3, 4, 5, 6]))
    composer.append(frame(rows: [4, 5, 6, 7, 8, 9]), overlap: overlap(offset: 3))

    XCTAssertEqual(composer.totalHeight, 9)
    let image = try composer.makeImage()
    XCTAssertEqual(image.width, width)
    XCTAssertEqual(image.height, 9)
    XCTAssertEqual(composer.pixels, Data(bytes(rows: [1, 2, 3, 4, 5, 6, 7, 8, 9])))
  }

  func testSeveralStepsChainThroughTheLatestFrame() throws {
    var composer = StripComposer(firstFrame: frame(rows: [1, 2, 3, 4]))
    composer.append(frame(rows: [3, 4, 5, 6]), overlap: overlap(offset: 2))
    composer.append(frame(rows: [6, 7, 8, 9]), overlap: overlap(offset: 3))

    XCTAssertEqual(try composer.makeImage().height, 9)
    XCTAssertEqual(composer.pixels, Data(bytes(rows: [1, 2, 3, 4, 5, 6, 7, 8, 9])))
  }

  func testStickyFooterAppearsOnceAtTheEnd() throws {
    let footer: UInt8 = 99
    var composer = StripComposer(firstFrame: frame(rows: [1, 2, 3, 4, 5, footer]))
    composer.append(frame(rows: [3, 4, 5, 6, 7, footer]), overlap: overlap(offset: 2, fixedBottom: 1))

    XCTAssertEqual(try composer.makeImage().height, 8)
    XCTAssertEqual(composer.pixels, Data(bytes(rows: [1, 2, 3, 4, 5, 6, 7, footer])))
  }

  func testMakeImageTwiceGivesTheSameImage() throws {
    var composer = StripComposer(firstFrame: frame(rows: [1, 2, 3]))
    composer.append(frame(rows: [2, 3, 4]), overlap: overlap(offset: 1))

    let first = try composer.makeImage()
    let second = try composer.makeImage()
    XCTAssertEqual(first.height, 4)
    XCTAssertEqual(second.height, 4)
    XCTAssertEqual(composer.pixels, Data(bytes(rows: [1, 2, 3, 4])))
  }

  func testImageReadsBackTheComposedBytes() throws {
    var composer = StripComposer(firstFrame: frame(rows: [10, 20, 30]))
    composer.append(frame(rows: [20, 30, 40]), overlap: overlap(offset: 1))

    let readBack = try FrameBuffer(cgImage: try composer.makeImage())
    XCTAssertEqual(readBack.pixels, bytes(rows: [10, 20, 30, 40]))
  }
}
