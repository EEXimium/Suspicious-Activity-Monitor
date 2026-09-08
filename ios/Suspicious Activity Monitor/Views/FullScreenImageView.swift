//
//  FullScreenImageView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 19.12.2024.
//


import SwiftUI

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0 
    @State private var offset = CGSize.zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    DragGesture()//resmi hareket ettir
                        .onChanged { gesture in
                            offset = gesture.translation
                        }
                        .onEnded { _ in
                            if abs(offset.height) > 150 {
                                dismiss()
                            } else {
                                offset = .zero
                            }
                        }
                )
                .gesture(
                    MagnificationGesture()//resmi büyüt
                        .onChanged { value in
                            scale = value.magnitude
                        }
                        .onEnded { _ in
                            if scale < 1.0 { scale = 1.0 }
                        }
                )
        }
    }
}
