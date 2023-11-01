import AppKit

extension NSEvent.ModifierFlags: ShortcutModifiers {
  var items: [ShortcutModifier] {
    var modifiers: [ShortcutModifier] = []
    
    if contains(.command) {
      modifiers.append(.cmd)
    }
    
    if contains(.option) {
      modifiers.append(.option)
    }
    
    if contains(.control) {
      modifiers.append(.ctrl)
    }
    
    if contains(.shift) {
      modifiers.append(.shift)
    }
    
    return modifiers
  }
}

extension Array where Element == ShortcutModifier {
  var modifierDescription: String {
    var string = ""
    
    for item in self.sorted() {
      string.append(item.description)
    }
    
    return string
  }
}

protocol ShortcutModifiers {
  var items: [ShortcutModifier] { get }
}

enum ShortcutModifier: Int, Comparable {
  case cmd
  case option
  case ctrl
  case shift
  
  static func < (lhs: ShortcutModifier, rhs: ShortcutModifier) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
  
  var description: String {
    switch self {
    case .cmd: return "⌘"
    case .option: return "⌥"
    case .ctrl: return "⌃"
    case .shift: return "⇧"
    }
  }
}

public class KeyCombo: NSObject, NSSecureCoding {

	// MARK: - Properties

	public var carbonKeyCode: UInt32
	public var carbonModifiers: UInt32
  
  public static var supportsSecureCoding: Bool = true

	public var key: HotKeyChar? {
		get {
      HotKeyChar(carbonKeyCode: carbonKeyCode)
		}

		set {
			carbonKeyCode = newValue?.carbonKeyCode ?? 0
		}
	}

	public var modifiers: NSEvent.ModifierFlags {
		get {
      NSEvent.ModifierFlags(carbonFlags: carbonModifiers)
		}
		set {
      carbonModifiers = newValue.carbonFlags
		}
	}

	public var isValid: Bool {
    carbonKeyCode >= 0
	}


	// MARK: - Initializers

  public required convenience init?(coder aDecoder: NSCoder) {
    guard
      let carbonKeyCode = aDecoder.decodeObject(forKey: "carbonKeyCode") as? UInt32,
      let carbonModifiers = aDecoder.decodeObject(forKey: "carbonModifiers") as? UInt32
    else { return nil }
    self.init(carbonKeyCode: carbonKeyCode, carbonModifiers: carbonModifiers)
  }
  
  public func encode(with aCoder: NSCoder) {
    aCoder.encode(carbonKeyCode, forKey: "carbonKeyCode")
    aCoder.encode(carbonModifiers, forKey: "carbonModifiers")
  }
  
	public init(carbonKeyCode: UInt32, carbonModifiers: UInt32 = 0) {
		self.carbonKeyCode = carbonKeyCode
		self.carbonModifiers = carbonModifiers
	}

	public init(key: HotKeyChar, modifiers: NSEvent.ModifierFlags = []) {
		self.carbonKeyCode = key.carbonKeyCode
		self.carbonModifiers = modifiers.carbonFlags
	}


	// MARK: - Converting Keys

	public static func carbonKeyCodeToString(_ carbonKeyCode: UInt32) -> String? {
    nil
	}
}


extension KeyCombo {
	public var dictionary: [String: Any] {
    ["keyCode": Int(carbonKeyCode), "modifiers": Int(carbonModifiers)]
	}

  public convenience init?(dictionary: [String: Any]) {
		guard let keyCode = dictionary["keyCode"] as? Int,
			let modifiers = dictionary["modifiers"] as? Int
		else {
			return nil
		}

		self.init(carbonKeyCode: UInt32(keyCode), carbonModifiers: UInt32(modifiers))
	}
}

extension KeyCombo {
	public static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
    lhs.carbonKeyCode == rhs.carbonKeyCode && lhs.carbonModifiers == rhs.carbonModifiers
	}
  
  public static func != (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
    !(lhs == rhs)
  }
}

// MARK: KeyCombo textual representation

extension KeyCombo {
  
  public var keyCodeDescription: String {
    let keyCodeString = HotKeyChar(carbonKeyCode: self.carbonKeyCode)?.rawValue ?? "?"
    return keyCodeString
  }
  
  override public var description: String {
    let keyCodeString = HotKeyChar(carbonKeyCode: self.carbonKeyCode)?.rawValue ?? "?"
    let keyComboString = "\(modifiers.items.modifierDescription)\(keyCodeString)"
    return keyComboString
  }
}
