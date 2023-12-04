import SwiftUI
import Foundation

class ComparePixelsViewModel: ObservableObject {
  @Published var image1: NSImage?
  @Published var image2: NSImage?
  @Published var image3: NSImage?
  
  
  let imcCrop = ImagesCropper()
  let imcProc = ImagesComparator()
  let imcStc = ImagesStitcher()
  
  func onAppear() {
      image1 = ImageLoader.getImage(with: "scroll0",
                                    resource: "png")
      
      let tmpImage2 = ImageLoader.getImage(with: "scroll1",
                                           resource: "png")
    
    /*  image2 = try! imcCrop.crop(tmpImage2,
                            rectInPixels: .init(x: 0, y: 25, width: 200, height: 25))
     */
      
      image2 = tmpImage2
    
      readPixels(image1: image1!, image2: image2!)
  }
    
    
    func readPixels(image1: NSImage, image2: NSImage) {
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
      
      let croppedImage = try! imcCrop.crop(image2, rectInPixels: .init(x: 0,
                                          y: CGFloat(cutYPosition),
                                               width: size.width,
                                               height: cutHeight))
  
      image3 = croppedImage
      
      
      // 4. Stitch the main image with the previous one
      let combinedImage = try! imcStc.combineTwoImagesVertically(image1: image1, image2: croppedImage)
      
      image3 = combinedImage
    

      
      print("FOUND row = \(foundRow)")

     // print(allPixels2.description)
    }

}


struct ComparePixelsView: View {
    @StateObject var viewModel = ComparePixelsViewModel()
    
    var body: some View {
        VStack {
            HStack {
              VStack {
                Text("Input 1")
                imageView(withImage: viewModel.image1)
              }
              VStack {
                Text("Input 1")
                imageView(withImage: viewModel.image2)
              }
            }
          VStack {
            Text("Output")
            imageView(withImage: viewModel.image3)
          }.padding()
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
    }
  
  func imageView(withImage image: NSImage?) -> some View {
    Image(nsImage: image ?? NSImage())
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 300, height: 300)
        .foregroundStyle(.tint)
        .border(Color.red)
  }
}

#Preview {
    ComparePixelsView()
}
