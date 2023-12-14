import Foundation
import Cocoa

class ComparePixelsViewModel: ObservableObject {
  // MARK: - Published
  @Published var image1: NSImage?
  @Published var image2: NSImage?
  @Published var image3: NSImage?
  
  // MARK: - Managers
  private let imcCrop = ImagesCropper()
  private let imcProc = ImagesComparator()
  private let imcStc = ImagesStitcher()
  
  // MARK: - Actions
  func onAppear() {
      image1 = ImageLoader.getImage(with: "Rectangle1",
                                    resource: "png")
      
      let tmpImage2 = ImageLoader.getImage(with: "Rectangle2",
                                           resource: "png")
    
    /*  image2 = try! imcCrop.crop(tmpImage2,
                            rectInPixels: .init(x: 0, y: 25, width: 200, height: 25))
     */
      
      image2 = tmpImage2
//
//      readPixels(image1: image1!, image2: image2!)
    
    combineTwoImagesFirstRowApproach(image1: image1!, image2: image2!)
  }
    
    
    func combineTwoImagesLatestRowApproach(image1: NSImage, image2: NSImage) {
      let date1 = Date()
    
    
      let diff = Date().timeIntervalSinceReferenceDate - date1.timeIntervalSinceReferenceDate
      print("Time to create contexts = \(diff)")
      
      let pixel1 = try! imcProc.pixel(from: image1,
                                      at: .init(x: 0, y: 25))
      let pixel2 = try! imcProc.pixel(from: image2,
                                      at: .init(x: 0, y: 25))
      
      print(pixel1)
      print(pixel2)
//
//      let allPixels1 = try! imcProc.allPixels(from: image1)
//      let allPixels2 = try! imcProc.allPixels(from: image2)
      
      
      // 1. Get the latest row from the image1
      let pixelRow1 = try! imcProc.latestRow(for: image1)
      
      // 2. try to found the same row in the image 2
      guard let foundRow = try! imcProc.findRow(pixelRow1, in: image2) else {
        print("Not found")
        return
      }
      
      
      //3. Cut the left part
      let cutYPosition = foundRow + 1
      
      let size = image2.size
      
      let cutHeight = size.height - CGFloat(cutYPosition)
      
      let croppedImage = try! imcCrop.crop(image2,
                                           rectInPixels: .init(x: 0,
                                                               y: CGFloat(cutYPosition),
                                                               width: size.width,
                                                               height: cutHeight))
  
      image3 = croppedImage
      
      
      // 4. Stitch the main image with the previous one
      let combinedImage = try! imcStc.combineTwoImagesVertically(image1: image1, image2: croppedImage)
      
      image3 = combinedImage
    

      
      print("FOUND row = \(foundRow)")
    }
  
  
  func combineTwoImagesFirstRowApproach(image1: NSImage, image2: NSImage) {
    // 1. Get the first row from the image 2
    let pixelRow1 = try! imcProc.firstRow(for: image2)
    
    // 2. try to found the same row in the image 1
    guard let foundRow = try! imcProc.findRow(pixelRow1, in: image1, startFromEnd: true) else {
      print("Not found")
      return
    }
    
    print("FOUND row = \(foundRow)")
    
    // 3.
    let cutYPosition = Int(image1.sizeInPixels.height) - foundRow + 1
    
    let size = image2.sizeInPixels
    
    let cutHeight = size.height - CGFloat(cutYPosition)
    
    // 4.
    
    let croppedImage = try! imcCrop.crop(image2,
                                         rectInPixels: .init(x: 0,
                                        y: CGFloat(cutYPosition),
                                                             width: size.width,
                                             height: cutHeight))
    
    // 4. Stitch the main image with the previous one
    let combinedImage = try! imcStc.combineTwoImagesVertically(image1: image1, image2: croppedImage)
    
    image3 = combinedImage
  }

}
