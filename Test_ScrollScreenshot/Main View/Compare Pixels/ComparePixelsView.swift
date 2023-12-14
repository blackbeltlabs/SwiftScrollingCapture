import SwiftUI
import Foundation

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
