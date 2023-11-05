import Foundation
import Cocoa
import ScreenCaptureKit

enum RecordingError: LocalizedError {
    case cantFindDisplayWithID
}



class ScreenshotTaker {
    private init() { }
    class func takeFullScreenScreenshot(_ displayId: CGDirectDisplayID, scale: Int, rect: CGRect) async throws -> CGImage {
        return try await takeFullScreenModern(displayId, scale: scale, cropRect: rect)
//        guard let img = CGDisplayCreateImage(displayId) else {
//          return nil
//        }
//        
//        return img
    }
    
    class func takeFullScreenModern(_ displayId: CGDirectDisplayID, scale: Int, cropRect: CGRect) async throws -> CGImage {
        let sharableContent = try await SCShareableContent.current
        
        // 2. Find the passed display among all displays
        guard let display = sharableContent.displays.first(where: { $0.displayID == displayId }) else {
            throw RecordingError.cantFindDisplayWithID
        }
        
        // 3. Set filter to record the passed display (with all windows and applications)
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // 4. Set up stream configuration
        let configuration = SCStreamConfiguration()
       
        // 5. Set up selection rect
        configuration.sourceRect = cropRect
        // Width and height are measured in pixels so
        // make sure to take display ScaleFactor into account
        // otherwise, image is scaled up and gets blurry (bec
        configuration.width = Int(cropRect.width) * scale
        configuration.height = Int(cropRect.height) * scale
          
        
        // 6. Set up color space and  matrix to sRGB
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.colorMatrix = CGDisplayStream.yCbCrMatrix_ITU_R_709_2
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
    
    
}


extension NSScreen {
    var displayID: CGDirectDisplayID {
      // swiftlint:disable:next force_cast
      (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
    }
}
