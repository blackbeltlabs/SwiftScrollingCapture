//
//  ScrollViewScroller.swift
//  Test_ScrollScreenshot
//
//  Created by Drapailo Yulian on 02.11.2023.
//

import Foundation
import CoreGraphics

class ScrollViewScroller {
  func scrollMouse(onPoint point: CGPoint, xLines: Int, yLines: Int) {
      guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: CGScrollEventUnit.line, wheelCount: 2, wheel1: Int32(yLines), wheel2: Int32(xLines), wheel3: 0) else {
          return
      }
      scrollEvent.setIntegerValueField(CGEventField.eventSourceUserData, value: 1)
      scrollEvent.post(tap: CGEventTapLocation.cghidEventTap)
  }
}




