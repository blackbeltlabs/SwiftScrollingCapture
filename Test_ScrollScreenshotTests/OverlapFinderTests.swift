import XCTest
@testable import Test_ScrollScreenshot

final class OverlapFinderTests: XCTestCase {
  private let finder = OverlapFinder()
  /// A page of unique text rows; frames are windows into it.
  private let page = TestRows.texts(0..<1000)
  private let height = 300

  private func frame(from start: Int) -> [RowSignature] {
    Array(page[start..<(start + height)])
  }

  private func overlap(offset: Int, top: Int = 0, bottom: Int = 0) -> OverlapResult {
    .overlap(FrameOverlap(fixedTop: top,
                          fixedBottom: bottom,
                          offset: offset,
                          rowsInPlaceTop: top,
                          rowsInPlaceBottom: bottom))
  }

  func testPlainScroll() {
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: frame(from: 150)), overlap(offset: 150))
  }

  func testShorterLastStepIsFoundAlthoughMoreWasExpected() {
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: frame(from: 40), expectedOffset: 150),
                   overlap(offset: 40))
  }

  func testStickyHeaderAndFooterAreLeftOutOfTheSearch() {
    let header = TestRows.texts(2000..<2020)
    let footer = TestRows.texts(3000..<3030)
    let previous = header + Array(page[0..<250]) + footer
    let next = header + Array(page[100..<350]) + footer

    XCTAssertEqual(finder.findOverlap(previous: previous, next: next), overlap(offset: 100, top: 20, bottom: 30))
  }

  func testBlankOverlapTrustsTheExpectedOffset() {
    // The text at the top scrolled out, new text came in at the bottom, and what overlaps is blank:
    // every offset fits, so only the requested distance can tell.
    let previous = TestRows.texts(0..<100) + TestRows.blanks(300)
    let next = TestRows.blanks(300) + TestRows.texts(500..<600)

    XCTAssertEqual(finder.findOverlap(previous: previous, next: next, expectedOffset: 250), overlap(offset: 250))
    XCTAssertEqual(finder.findOverlap(previous: previous, next: next), .notFound)
  }

  func testBlinkingCaretAtTheEndOfThePageIsIdentical() {
    var next = frame(from: 0)
    next.replaceSubrange(150..<160, with: TestRows.texts(900..<910))

    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: next, expectedOffset: 150), .identical)
  }

  func testRepeatedRowsAtTheEndOfThePageAreNotTakenForAScroll() {
    // A list of identical items: shifted by one item it matches almost everywhere. With a caret blinking
    // in the middle the frames are not equal, but nothing scrolled.
    let item = TestRows.texts(0..<8)
    let previous = (0..<height).map { item[$0 % item.count] }
    var next = previous
    next.replaceSubrange(150..<160, with: TestRows.texts(900..<910))

    XCTAssertEqual(finder.findOverlap(previous: previous,
                                      next: next,
                                      expectedOffset: 150,
                                      knownStickyParts: StickyParts(top: 0, bottom: 0)),
                   .identical)
  }

  func testScrollPastTheWholeAreaIsNotFound() {
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: frame(from: 300), expectedOffset: 150),
                   .notFound)
  }

  func testUnchangedFrameIsIdentical() {
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: frame(from: 0)), .identical)
  }

  func testReRasterisedRowsStillMatch() {
    // Every row of the next frame has other bytes, but the same ink per band.
    let next = frame(from: 150).map { TestRows.reRasterised($0) }
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: next), overlap(offset: 150))

    let withinTolerance = frame(from: 150).map { TestRows.reRasterised($0, bandShift: RowSignature.bandTolerance) }
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: withinTolerance), overlap(offset: 150))
  }

  func testRowsBeyondTheBandToleranceDoNotMatch() {
    let next = frame(from: 150).map { TestRows.reRasterised($0, bandShift: RowSignature.bandTolerance + 1) }
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: next), .notFound)
  }

  func testSmallDynamicPartInsideTheOverlapIsTolerated() {
    var next = frame(from: 150)
    next.replaceSubrange(20..<30, with: TestRows.texts(900..<910))

    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: next), overlap(offset: 150))
  }

  func testFramesOfDifferentHeightAreNotCompared() {
    XCTAssertEqual(finder.findOverlap(previous: frame(from: 0), next: Array(page[0..<299])), .notFound)
  }
}
