//
//  RotatingDotModifier.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 02/01/2026.
//


import SwiftUI

struct RotatingDotModifier: ViewModifier {
    @Binding var isActive: Bool
    @State private var rotation: Double = 0
	@State private var timer: Timer?

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
							//.overlay( Circle().stroke(Color.black, lineWidth: 0.5) )
							.shadow(radius: 2)
                            .offset(y: -22)
                            .rotationEffect(.degrees(rotation))
							.onAppear {
								startTimer()
							}
							.onDisappear {
								stopTimer()
							}
                    }
                }
            )
            .onChange(of: isActive) { _, newValue in
				if newValue {
					startTimer()
				} else {
					stopTimer()
				}
            }
    }
	
	private func startTimer() {
		stopTimer()
		rotation = 0
		timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
			withAnimation(.linear(duration: 0.016)) {
				rotation += 1.92 // 360 / (3 / 0.016) for 3s per rotation
				if rotation >= 360 { rotation -= 360 }
			}
		}
	}

	private func stopTimer() {
		timer?.invalidate()
		timer = nil
		rotation = 0
	}
}

extension View {
    func rotatingDot(isActive: Binding<Bool>) -> some View {
        self.modifier(RotatingDotModifier(isActive: isActive))
    }
}
