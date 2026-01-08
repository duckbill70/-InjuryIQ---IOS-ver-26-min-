//
//  SessionControlButton.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import SwiftUI

public struct SessionControlButton: View {
	//@Binding var state: SessionState


	//public init(state: Binding<SessionState>) {
	//	self._state = state
	//}
	var selectedActivity: String

	public var body: some View {
		HStack(spacing: 12) {
			RunPauseButton(selectedActivity: self.selectedActivity)
			StopButton()
		}
	}
}

#Preview {
	@Previewable @State var state: SessionState = .stopped
	VStack(spacing: 16) {
		SessionControlButton(selectedActivity: "Running")
		Text("State: \(state.rawValue)")
	}
	.padding()
}
