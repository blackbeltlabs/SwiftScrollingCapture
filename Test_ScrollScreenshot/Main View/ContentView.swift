//
//  ContentView.swift
//  Test_ScrollScreenshot
//
//  Created by Drapailo Yulian on 15.10.2023.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
          Image(nsImage: viewModel.image ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 600, height: 600)
            .foregroundStyle(.tint)
            .border(Color.red)
       
          Button("Take screenshot") {
            Task {
              await viewModel.takeScreenshot()
              }
          }
          Button("Present selection area") {
            viewModel.presentSelectionArea()
          }
          
          Button("Request accessibility permissions") {
            viewModel.requestAccessibilityPressed()
          }
          
          Button("Test merge two images") {
            viewModel.mergeTwoImagesPressed()
          }
        
          Button("Compare two images") {
            viewModel.compareTwoImagesPressed()
          }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
