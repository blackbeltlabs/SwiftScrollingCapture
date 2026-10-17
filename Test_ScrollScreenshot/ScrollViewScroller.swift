//
//  ScrollViewScroller.swift
//  Test_ScrollScreenshot
//
//  Created by Drapailo Yulian on 02.11.2023.
//

import Foundation
import CoreGraphics

/// Posting events requires the Accessibility permission (see `AccessibilityPermissionsManager`).
/// All points are global Quartz coordinates (origin at the top-left of the primary display).
class ScrollViewScroller {
  /// Scroll wheel events are delivered to the view under the cursor, so the cursor has to be over the scrolled view.
  func moveCursor(to point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    CGAssociateMouseAndMouseCursorPosition(1)
  }

  /// Scrolls by a distance in points. Negative values move the content up (towards the end of the page).
  func scroll(byPoints points: Int32, at point: CGPoint) {
    guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                    units: .pixel,
                                    wheelCount: 1,
                                    wheel1: points,
                                    wheel2: 0,
                                    wheel3: 0) else {
      return
    }
    scrollEvent.location = point
    scrollEvent.setIntegerValueField(CGEventField.eventSourceUserData, value: 1)
    scrollEvent.post(tap: CGEventTapLocation.cghidEventTap)
  }
}
