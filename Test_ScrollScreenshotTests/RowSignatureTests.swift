import XCTest
@testable import Test_ScrollScreenshot

final class RowSignatureTests: XCTestCase {
  func testEqualHashIsSimilar() {
    let row = TestRows.text(7)
    XCTAssertTrue(row.isSimilar(to: row))
  }

  func testOtherHashWithBandsWithinToleranceIsSimilar() {
    let row = TestRows.text(7)
    XCTAssertTrue(row.isSimilar(to: TestRows.reRasterised(row)))
    XCTAssertTrue(row.isSimilar(to: TestRows.reRasterised(row, bandShift: RowSignature.bandTolerance)))
  }

  func testOneBandBeyondToleranceIsNotSimilar() {
    let row = TestRows.text(7)
    XCTAssertFalse(row.isSimilar(to: TestRows.reRasterised(row, bandShift: RowSignature.bandTolerance + 1)))
  }

  func testDifferentTextRowsAreNotSimilar() {
    XCTAssertFalse(TestRows.text(7).isSimilar(to: TestRows.text(8)))
    XCTAssertFalse(TestRows.text(0).isSimilar(to: TestRows.text(85)))
  }

  func testUniformAndNonUniformRowsAreNotSimilarThroughBands() {
    // Same band means, only the flag differs: a hairline on a blank background must stay distinct from blank.
    let hairline = RowSignature(hash: 1, isUniform: false, bands: TestRows.blank.bands)
    XCTAssertFalse(TestRows.blank.isSimilar(to: hairline))
    XCTAssertFalse(hairline.isSimilar(to: TestRows.blank))
  }

  func testExactEqualityIgnoresNothing() {
    let row = TestRows.text(7)
    XCTAssertNotEqual(row, TestRows.reRasterised(row))
    XCTAssertEqual(row, TestRows.text(7))
  }
}
