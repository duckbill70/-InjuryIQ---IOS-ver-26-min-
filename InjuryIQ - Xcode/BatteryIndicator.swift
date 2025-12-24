//
//  BatteryIndicator.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 18/12/2025.
//
import SwiftUI

struct BatteryIndicator: View {
	var level: Int? // 0...100

	var body: some View {
		let pct = CGFloat(min(100, max(0, level ?? 0))) / 100.0
		ZStack(alignment: .leading) {
			RoundedRectangle(cornerRadius: 3)
				.stroke(Color.gray.opacity(0.6), lineWidth: 1)
				.frame(width: 34, height: 14)
			RoundedRectangle(cornerRadius: 2)
				.fill(fill(for: pct))
				.frame(width: 32 * pct, height: 10)
				.padding(.leading, 1)
		}
		.overlay(
			Rectangle()
				.fill(Color.gray.opacity(0.6))
				.frame(width: 3, height: 6)
				.offset(x: 19, y: 0),
			alignment: .trailing
		)
		.accessibilityLabel(Text("Battery \(level.map { "\($0)%" } ?? "unknown")"))
	}

	private func fill(for pct: CGFloat) -> Color {
		switch pct {
		case ..<0.2: return .red
		case ..<0.5: return .orange
		default: return .green
		}
	}
}
