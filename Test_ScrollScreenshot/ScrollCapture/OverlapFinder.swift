import Foundation

/// How the next frame relates to the previous one.
struct FrameOverlap: Equatable {
  /// Rows at the top that did not move (sticky header, toolbar).
  let fixedTop: Int
  /// Rows at the bottom that did not move (sticky footer, status bar).
  let fixedBottom: Int
  /// How many rows the content between the fixed parts moved up.
  /// Row `r` of the previous frame is row `r - offset` of the next frame.
  let offset: Int
  /// Rows at the top / bottom that were equal in both frames. Can be more than the sticky part if the content
  /// next to it happened to be the same too, so the smallest value across steps is the sticky part's size.
  let rowsInPlaceTop: Int
  let rowsInPlaceBottom: Int
}

/// Sizes of the sticky parts known from earlier steps.
struct StickyParts: Equatable {
  var top: Int
  var bottom: Int
}

enum OverlapResult: Equatable {
  /// Nothing moved: the end of the content is reached (or the scroll event did not land).
  case identical
  case overlap(FrameOverlap)
  /// Frames differ but no reliable overlap was found
  /// (scrolled further than one frame, content changed while scrolling, ...).
  case notFound
}

/// Finds the vertical scroll offset between two consecutive frames of the same size.
///
/// Instead of looking for one row (which is ambiguous for blank / repeated rows), every candidate offset
/// is scored by how many rows of the whole overlapping area match, and the best candidate wins.
struct OverlapFinder {
  /// Share of rows in the overlapping area that must match.
  /// Below 1.0 to tolerate small dynamic parts (blinking caret, cursor, animated icon).
  var minimumMatchRatio: Double = 0.9
  /// Minimum number of matching non-uniform rows, so blank areas alone can't produce a match.
  var minimumDistinctRows: Int = 8
  /// Minimum size of the overlapping area.
  var minimumOverlapRows: Int = 16

  /// - Parameters:
  ///   - expectedOffset: how far we asked to scroll, in pixels. Used to pick between equally good matches.
  ///   - knownStickyParts: smallest `rowsInPlaceTop` / `rowsInPlaceBottom` seen in earlier steps.
  func findOverlap(previous: [RowSignature],
                   next: [RowSignature],
                   expectedOffset: Int? = nil,
                   knownStickyParts: StickyParts? = nil) -> OverlapResult {
    guard previous.count == next.count, !previous.isEmpty else {
      return .notFound
    }

    let height = previous.count

    // 1. Rows that stayed in place at the top / bottom are sticky parts, they are not searched.
    var fixedTop = 0
    while fixedTop < height && previous[fixedTop] == next[fixedTop] {
      fixedTop += 1
    }

    if fixedTop == height {
      return .identical
    }

    var fixedBottom = 0
    while fixedBottom < height - fixedTop && previous[height - 1 - fixedBottom] == next[height - 1 - fixedBottom] {
      fixedBottom += 1
    }

    // 2. Content next to a sticky part can be the same in both frames by chance (usually blank space),
    // which makes the sticky part look taller. Candidates for the real sticky parts, most likely first:
    // - as detected;
    // - the smallest sizes seen in earlier steps;
    // - without the blank rows at their inner edge. Those can be the part's own padding (or window background
    //   around the scroll view), which really doesn't move, or blank content: one pair can't tell which.
    var candidates = [StickyParts(top: fixedTop, bottom: fixedBottom)]
    if let knownStickyParts {
      candidates.append(StickyParts(top: min(fixedTop, knownStickyParts.top),
                                    bottom: min(fixedBottom, knownStickyParts.bottom)))
    }
    candidates.append(StickyParts(
      top: previous[0..<fixedTop].lastIndex(where: { !$0.isUniform }).map { $0 + 1 } ?? 0,
      bottom: previous[(height - fixedBottom)..<height].firstIndex(where: { !$0.isUniform }).map { height - $0 } ?? 0
    ))

    var uniqueCandidates: [StickyParts] = []
    for candidate in candidates where !uniqueCandidates.contains(candidate) {
      uniqueCandidates.append(candidate)
    }

    func overlap(_ sticky: StickyParts, offset: Int) -> OverlapResult {
      .overlap(FrameOverlap(fixedTop: sticky.top,
                            fixedBottom: sticky.bottom,
                            offset: offset,
                            rowsInPlaceTop: fixedTop,
                            rowsInPlaceBottom: fixedBottom))
    }

    for sticky in uniqueCandidates {
      if let offset = bestOffset(previous: previous,
                                 next: next,
                                 regionStart: sticky.top,
                                 regionHeight: height - sticky.top - sticky.bottom,
                                 expectedOffset: expectedOffset) {
        return overlap(sticky, offset: offset)
      }
    }

    // 3. No movement proven. If almost everything is still in place, only a small dynamic part changed
    // (e.g. a blinking caret) and the content did not scroll. This goes before step 4: at the end of a page
    // a blank area "fits" any offset, and trusting the requested distance there would add blank rows forever.
    let rowsInPlace = zip(previous, next).reduce(0) { $0 + ($1.0 == $1.1 ? 1 : 0) }
    if Double(rowsInPlace) >= Double(height) * minimumMatchRatio {
      return .identical
    }

    // 4. The overlapping area is (almost) blank, so any offset fits and nothing proves the right one.
    // Trust the distance we asked to scroll, if the frames don't contradict it.
    if let expectedOffset {
      for sticky in uniqueCandidates where isConsistent(previous: previous,
                                                        next: next,
                                                        regionStart: sticky.top,
                                                        regionHeight: height - sticky.top - sticky.bottom,
                                                        offset: expectedOffset) {
        return overlap(sticky, offset: expectedOffset)
      }
    }

    return .notFound
  }

  /// Scores every offset and returns the best one that has enough non-blank evidence.
  private func bestOffset(previous: [RowSignature],
                          next: [RowSignature],
                          regionStart: Int,
                          regionHeight: Int,
                          expectedOffset: Int?) -> Int? {
    guard regionHeight > minimumOverlapRows else {
      return nil
    }

    // Scored by the number of matching rows, so a large overlap with a few dynamic rows beats a small
    // overlap that matches perfectly by chance (e.g. repeated table rows).
    var best: (offset: Int, matchedRows: Int)?

    for offset in 1...(regionHeight - minimumOverlapRows) {
      let overlapRows = regionHeight - offset
      guard let comparison = compare(previous: previous,
                                     next: next,
                                     regionStart: regionStart,
                                     overlapRows: overlapRows,
                                     offset: offset),
            comparison.distinctMatches >= minimumDistinctRows else {
        continue
      }

      let matchedRows = overlapRows - comparison.mismatches

      if let current = best {
        if matchedRows > current.matchedRows {
          best = (offset, matchedRows)
        } else if matchedRows == current.matchedRows, let expectedOffset,
                  abs(offset - expectedOffset) < abs(current.offset - expectedOffset) {
          // Several offsets can match equally well: prefer the one closest to how far we asked to scroll.
          best = (offset, matchedRows)
        }
      } else {
        best = (offset, matchedRows)
      }
    }

    return best?.offset
  }

  private func isConsistent(previous: [RowSignature],
                            next: [RowSignature],
                            regionStart: Int,
                            regionHeight: Int,
                            offset: Int) -> Bool {
    guard offset >= 1, offset <= regionHeight - minimumOverlapRows else {
      return false
    }
    return compare(previous: previous,
                   next: next,
                   regionStart: regionStart,
                   overlapRows: regionHeight - offset,
                   offset: offset) != nil
  }

  /// Compares `previous[regionStart + offset + k]` with `next[regionStart + k]` for every row of the overlap.
  /// Returns nil as soon as there are more mismatches than `minimumMatchRatio` allows.
  private func compare(previous: [RowSignature],
                       next: [RowSignature],
                       regionStart: Int,
                       overlapRows: Int,
                       offset: Int) -> (mismatches: Int, distinctMatches: Int)? {
    let allowedMismatches = Int(Double(overlapRows) * (1.0 - minimumMatchRatio))
    var mismatches = 0
    var distinctMatches = 0

    for k in 0..<overlapRows {
      let previousRow = previous[regionStart + offset + k]
      if previousRow == next[regionStart + k] {
        if !previousRow.isUniform {
          distinctMatches += 1
        }
      } else {
        mismatches += 1
        if mismatches > allowedMismatches {
          return nil
        }
      }
    }

    return (mismatches, distinctMatches)
  }
}
