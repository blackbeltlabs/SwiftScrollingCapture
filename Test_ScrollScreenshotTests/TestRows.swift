import Foundation
@testable import Test_ScrollScreenshot

/// Synthetic row signatures for the overlap tests: no images needed, every property is explicit.
enum TestRows {
  /// A non-blank row whose hash and band profile are unique to `id`. The id is written in base 36 across the
  /// bands, each digit scaled by 7, so two different ids differ by at least 7 levels in some band and never
  /// pass `isSimilar(to:)`; and a band shifted by `bandTolerance + 1` (3) stays at least 3 levels away from
  /// every other id's profile, so it matches no row at all.
  static func text(_ id: Int) -> RowSignature {
    var bands = SIMD16<UInt8>()
    var rest = id
    for band in 0..<RowSignature.bandCount {
      bands[band] = UInt8((rest % 36) * 7)
      rest /= 36
    }
    return RowSignature(hash: UInt64(id) &* 0x9E37_79B9_7F4A_7C15 ^ 0xABCD_EF01,
                        isUniform: false,
                        bands: bands)
  }

  static func texts(_ ids: Range<Int>) -> [RowSignature] {
    ids.map(text)
  }

  /// A blank row: every blank row is equal to every other one.
  static let blank = RowSignature(hash: 0, isUniform: true, bands: SIMD16<UInt8>(repeating: 255))

  static func blanks(_ count: Int) -> [RowSignature] {
    Array(repeating: blank, count: count)
  }

  /// The same content rasterised with another subpixel phase: other bytes, so another hash, but (almost)
  /// the same amount of ink per band.
  static func reRasterised(_ row: RowSignature, bandShift: UInt8 = 0) -> RowSignature {
    var bands = row.bands
    if bandShift > 0 {
      bands[0] = bands[0] &+ bandShift
    }
    return RowSignature(hash: row.hash ^ 0xFFFF_FFFF_FFFF_FFFF, isUniform: row.isUniform, bands: bands)
  }
}
