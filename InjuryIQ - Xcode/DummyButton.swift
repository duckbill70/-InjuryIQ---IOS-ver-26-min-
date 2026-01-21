//
//  StopButton.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 17/01/2026.
//
import SwiftUI


struct DummyButton: View {
	@Environment(Session.self) var session

	private let size: CGFloat = 70

	var body: some View {
		Button {
			session.stop()
		} label: {
			Image(systemName: "lock.slash.fill")
				.font(.system(size: 26, weight: .semibold))
				.frame(width: size, height: size)
				.background(
					Circle().fill(Color.gray.opacity(0.18))
				)
				.foregroundStyle(Color.gray)
				.overlay(
					Circle().stroke(Color.gray.opacity(0.35), lineWidth: 1)
				)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text("Placeholder Button - Disabled"))
		.disabled(true)
	}
}

#Preview {
	let session = Session()
	DummyButton()
		.environment(session)
}
