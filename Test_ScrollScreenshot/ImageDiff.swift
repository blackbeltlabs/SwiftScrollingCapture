//
//  ImageDiff.swift
//  Test_ScrollScreenshot
//
//  Created by Drapailo Yulian on 04.11.2023.
//

import CoreGraphics
import CoreImage

class ImageDiff {

  func compare(leftImage: CGImage, rightImage: CGImage) throws -> Int {

    let left = CIImage(cgImage: leftImage)
    let right = CIImage(cgImage: rightImage)

    guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else {
      throw ImageDiffError.failedToCreateFilter
    }
    diffFilter.setDefaults()
    diffFilter.setValue(left, forKey: kCIInputImageKey)
    diffFilter.setValue(right, forKey: kCIInputBackgroundImageKey)

    // Create the area max filter and set its properties.
    guard let areaMaxFilter = CIFilter(name: "CIAreaMaximum") else {
      throw ImageDiffError.failedToCreateFilter
    }
    areaMaxFilter.setDefaults()
    areaMaxFilter.setValue(diffFilter.value(forKey: kCIOutputImageKey),
                           forKey: kCIInputImageKey)
    let compareRect = CGRect(x: 0, y: 0, width: CGFloat(leftImage.width), height: CGFloat(leftImage.height))

    let extents = CIVector(cgRect: compareRect)
    areaMaxFilter.setValue(extents, forKey: kCIInputExtentKey)

    // The filters have been setup, now set up the CGContext bitmap context the
    // output is drawn to. Setup the context with our supplied buffer.
    let alphaInfo = CGImageAlphaInfo.premultipliedLast
    let bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    var buf: [CUnsignedChar] = Array<CUnsignedChar>(repeating: 255, count: 16)

    guard let context = CGContext(
      data: &buf,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 16,
      space: colorSpace,
      bitmapInfo: bitmapInfo.rawValue
    ) else {
      throw ImageDiffError.failedToCreateContext
    }

    // Now create the core image context CIContext from the bitmap context.
    let ciContextOpts = [
      CIContextOption.workingColorSpace : colorSpace,
      CIContextOption.useSoftwareRenderer : false
    ] as [CIContextOption : Any]
    let ciContext = CIContext(cgContext: context, options: ciContextOpts)

    // Get the output CIImage and draw that to the Core Image context.
    let valueImage = areaMaxFilter.value(forKey: kCIOutputImageKey)! as! CIImage
    ciContext.draw(valueImage, in: CGRect(x: 0, y: 0, width: 1, height: 1),
                   from: valueImage.extent)

    // This will have modified the contents of the buffer used for the CGContext.
    // Find the maximum value of the different color components. Remember that
    // the CGContext was created with a Premultiplied last meaning that alpha
    // is the fourth component with red, green and blue in the first three.
    let maxVal = max(buf[0], max(buf[1], buf[2]))
    let diff = Int(maxVal)

    return diff
  }
}

// MARK: - Supporting Types

enum ImageDiffError: LocalizedError {
  case failedToCreateFilter
  case failedToCreateContext
}
