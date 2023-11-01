import Cocoa

public final class AccessibilityPermissionsManager {
  public var accesibilityEnabled: Bool {
    AXIsProcessTrusted()
  }
  
  public func requestAccessibility() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
    _ = AXIsProcessTrustedWithOptions(options)
  }
}
