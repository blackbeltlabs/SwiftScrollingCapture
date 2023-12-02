import Foundation
import Cocoa

final class ImageLoader {
    init() { }
    
    static func getImage(with name: String, resource: String) -> NSImage {
        let url = Bundle.main.url(forResource: name, withExtension: resource)!
        let data = try! Data(contentsOf: url)
        return NSImage(data: data)!
    }
}
