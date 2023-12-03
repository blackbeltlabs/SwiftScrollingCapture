import SwiftUI
import Foundation

class ComparePixelsViewModel: ObservableObject {
    @Published var image1: NSImage?
    @Published var image2: NSImage?
    
    let imcCrop = ImagesCropper()
    let imcProc = ImagesComparator()
    
    func onAppear() {
        image1 = ImageLoader.getImage(with: "Rectangle1",
                                      resource: "png")
        
        let tmpImage2 = ImageLoader.getImage(with: "Rectangle2",
                                             resource: "png")
      
      /*  image2 = try! imcCrop.crop(tmpImage2,
                              rectInPixels: .init(x: 0, y: 25, width: 200, height: 25))
       */
        
        image2 = tmpImage2
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
      
      let pixelRow1 = try! imcProc.pixelsRow(from: image1, row: 30)
      let pixelRow2 = try! imcProc.pixelsRow(from: image2, row: 30)
      
      print(pixelRow1 == pixelRow2)

     // print(allPixels2.description)
    }

}


struct ComparePixelsView: View {
    @StateObject var viewModel = ComparePixelsViewModel()
    
    var body: some View {
        HStack {
            Image(nsImage: viewModel.image1 ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .foregroundStyle(.tint)
                .border(Color.red)
            
            Image(nsImage: viewModel.image2 ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .foregroundStyle(.tint)
                .border(Color.red)
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview {
    ComparePixelsView()
}
