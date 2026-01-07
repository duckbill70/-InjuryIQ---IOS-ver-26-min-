import SwiftUI
import Foundation


///@State private var selectedValue: [Int]  = 0
///
///IntervalSlider(
/// min: 0,
/// max: 10,
/// intervalCount: 10,
/// isDisabled: false,
/// value: $v,
/// selectedValue: { selectedValue = $0 }, // <-- receives [Int] with the selected value
/// onValueChanged: { _ in }
///)

public struct IntervalSlider: View {
	public let max: Double
	public let min: Double
	/// Number of intervals (segments). Example: 10 => step = max/10, values: 0...max.
	public let intervalCount: Int
	public let isDisabled: Bool

	/// Selected value (0...max, snapped by intervalCount)
	@Binding public var value: Double

	/// Returns the three marker numbers (max/3, 2*max/3, max) whenever `max` changes (and on appear).
	public var selectedValue: (([Int]) -> Void)?
	/// Not required, but handy if you want side-effects when value changes.
	public var onValueChanged: ((Double) -> Void)?

	public init(
		min: Double = 0,
		max: Double,
		intervalCount: Int,
		isDisabled: Bool = false,
		value: Binding<Double>,
		selectedValue: (([Int]) -> Void)? = nil,
		onValueChanged: ((Double) -> Void)? = nil
	) {
		self.min = min
		self.max = max
		self.intervalCount = Swift.max(1, intervalCount)
		self.isDisabled = isDisabled
		self._value = value
		self.selectedValue = selectedValue
		self.onValueChanged = onValueChanged
	}

	public var body: some View {
		//let step = max / Double(Swift.max(1, intervalCount))
		//let step = 1.0
		let step = (max - min) / Double(intervalCount)

		GlassCard {
			VStack(alignment: .leading, spacing: 10) {

				// Header
				HStack {
					Text("DISTANCE")
						.font(.headline.weight(.semibold))
					Spacer()
					Text(displayValue)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}

				// Track + ticks
				ZStack {
					// Track background
					Capsule()
						.fill(.ultraThinMaterial)
						.overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
						.frame(height: 46)

					// Subtle tick marks
					HStack(spacing: 0) {
						ForEach(0..<tickCount, id: \.self) { i in
							Rectangle()
								.fill(Color.white.opacity(i.isMultiple(of: Swift.max(1, tickCount / 4)) ? 0.12 : 0.06))
								.frame(width: 1)
								.frame(maxWidth: .infinity)
						}
					}
					.padding(.horizontal, 16)
					.frame(height: 20)
					.allowsHitTesting(false)
					.opacity(0.9)

					// Native slider on top (transparent track; we provide our own visuals)
					Slider(value: $value, in: min...max, step: step)
						.tint(.white) // keeps the thumb readable over glass; doesn’t force your brand color
						.padding(.horizontal, 14)
						.onChange(of: value) { _, newValue in
							onValueChanged?(newValue)
						}
				}
				.opacity(isDisabled ? 0.35 : 1.0)
				.disabled(isDisabled)

				// 3 markers below (max/3, 2*max/3, max)
				HStack {
					Text(format(markers[0]))
					Spacer()
					Text(format(markers[1]))
					Spacer()
					Text(format(markers[2]))
				}
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
				.monospacedDigit()

			}
			.opacity(isDisabled ? 0.55 : 1.0)
		}
		.onAppear { selectedValue?([Int(value.rounded())]) }
		.onChange(of: max) { _, _ in selectedValue?([Int(value.rounded())]) }
		.onChange(of: value) { _, newValue in
			onValueChanged?(newValue)
			selectedValue?([Int(newValue.rounded())]) // Add this line
		}
	}

	// MARK: - Derived

	private var markers: [Double] {
		let step = (max - min) / 2.0
		return [min, min + step, max]
	}

	private var displayValue: String {
		// If max is an integer-ish, show as integer; otherwise 1dp.
		if abs(max.rounded() - max) < 0.0001 {
			return "\(Int(value.rounded())) / \(Int(max.rounded()))"
		} else {
			return "\(String(format: "%.1f", value)) / \(String(format: "%.1f", max))"
		}
	}

	private var tickCount: Int {
		// Visual ticks: slightly more than intervals, capped for performance.
		Swift.min(Swift.max(8, intervalCount + 1), 28)
	}

	private func format(_ x: Double) -> String {
		if abs(max.rounded() - max) < 0.0001 {
			return "\(Int(x.rounded()))"
		} else {
			return String(format: "%.1f", x)
		}
	}
}

// MARK: - Same GlassCard style as your other components

public struct GlassCard<Content: View>: View {
	@ViewBuilder var content: () -> Content
	public init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }

	public var body: some View {
		VStack { content() }
			.padding(14)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
			)
			.shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
			.padding()
	}
}

// MARK: - Preview

#Preview("IntervalSlider") {
	struct Demo: View {
		@State var v: Double = 0
		@State var selectedValue: [Int] = []

		var body: some View {
			ZStack {
				LinearGradient(
					colors: [Color.blue.opacity(0.12), Color(.systemBackground), Color.purple.opacity(0.10)],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()

				VStack(spacing: 6) {
					IntervalSlider(
						min: 0,
						max: 10,
						intervalCount: 10,
						isDisabled: false,
						value: $v,
						selectedValue: { selectedValue = $0 },
						onValueChanged: { _ in }
					)

					Text("Markers returned: \(selectedValue.map(String.init).joined(separator: ", "))")
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.horizontal)
				}
			}
		}
	}

	return Demo()
}

