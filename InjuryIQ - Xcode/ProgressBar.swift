import SwiftUI

/// A standalone, reusable progress bar with a “data flowing” look.
/// - Supports subtle shimmer when `isActive == true`
/// - Optional “near full” pulse when `progress >= nearFullThreshold`
/// - Texture (waveforms) inside the fill (not a big watermark)
public struct DataFlowProgressBar: View {
	public let progress: Double          // 0...1
	public let isActive: Bool
	public let height: CGFloat
	public let nearFullThreshold: Double

	/// Optional: override the label (e.g. "2.4 km" or "62%").
	public let label: String?

	/// Optional: force a single tint style; otherwise uses semantic colors.
	public let tint: Color?

	@State private var shimmerPhase: CGFloat = 0
	@State private var pulse = false

	public init(
		progress: Double,
		isActive: Bool = false,
		height: CGFloat = 54,
		nearFullThreshold: Double = 0.95,
		label: String? = nil,
		tint: Color? = nil
	) {
		self.progress = progress
		self.isActive = isActive
		self.height = height
		self.nearFullThreshold = nearFullThreshold
		self.label = label
		self.tint = tint
	}

	public var body: some View {
		GeometryReader { geo in
			let w = geo.size.width
			let p = clamp(progress)
			let fillW = p * w

			ZStack {
				// Track: glass capsule
				Capsule()
					.fill(.ultraThinMaterial)
					.overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
					.shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)

				// Subtle instrument ticks
				HStack(spacing: 0) {
					ForEach(0..<12) { i in
						Rectangle()
							.fill(Color.white.opacity(i.isMultiple(of: 3) ? 0.10 : 0.05))
							.frame(width: w / 12)
					}
				}
				.clipShape(Capsule())
				.opacity(0.70)

				// Fill
				ZStack(alignment: .leading) {
					Capsule().fill(Color.clear)

					Capsule()
						.fill(fillGradient(for: p))
						.frame(width: fillW)
						.overlay(waveTexture.mask(Capsule().frame(width: fillW)))
						.overlay(shimmerOverlay.mask(Capsule().frame(width: fillW)))
						.overlay(
							Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
								.frame(width: fillW)
						)
						.opacity(p == 0 ? 0 : 1)
						.animation(.easeInOut(duration: 0.25), value: p)
				}
				.clipShape(Capsule())

				// Label pill (right aligned)
				if let labelText = labelText(for: p) {
					HStack {
						Spacer()
						Text(labelText)
							.font(.caption.weight(.semibold))
							.padding(.horizontal, 10)
							.padding(.vertical, 6)
							.background(.ultraThinMaterial)
							.clipShape(Capsule())
							.overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
							.padding(.trailing, 10)
					}
				}

				// Near-full pulse cue
				if p >= nearFullThreshold {
					Capsule()
						.strokeBorder(Color.green.opacity(pulse ? 0.20 : 0.45), lineWidth: 2)
						.animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
						.padding(1)
				}
			}
			.frame(height: height)
			.onAppear {
				pulse = true
				startShimmerIfNeeded()
			}
			.onChange(of: isActive) { _, _ in
				startShimmerIfNeeded()
			}
		}
		.frame(height: height)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityText)
	}

	// MARK: - Subviews

	private var waveTexture: some View {
		HStack(spacing: 6) {
			Image(systemName: "waveform.path.ecg")
				.font(.system(size: 16, weight: .semibold))
				.opacity(0.22)
			Image(systemName: "waveform")
				.font(.system(size: 16, weight: .semibold))
				.opacity(0.18)
			Image(systemName: "waveform.path.ecg")
				.font(.system(size: 16, weight: .semibold))
				.opacity(0.22)
		}
		.foregroundStyle(.white)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.leading, 16)
	}

	private var shimmerOverlay: some View {
		Rectangle()
			.fill(
				LinearGradient(
					colors: [
						Color.white.opacity(0.0),
						Color.white.opacity(0.22),
						Color.white.opacity(0.0)
					],
					startPoint: .top,
					endPoint: .bottom
				)
			)
			.rotationEffect(.degrees(18))
			.offset(x: isActive ? (shimmerPhase * 240 - 120) : -9999)
	}

	// MARK: - Helpers

	private func labelText(for p: Double) -> String? {
		if let label { return label }
		return "\(Int(round(p * 100)))%"
	}

	private var accessibilityText: String {
		let pct = Int(round(clamp(progress) * 100))
		return "Progress \(pct) percent"
	}

	private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }

	private func fillGradient(for p: Double) -> LinearGradient {
		let baseTint = tint

		// If user supplies tint, keep it rich but subtle.
		if let baseTint {
			return LinearGradient(
				colors: [baseTint.opacity(0.90), baseTint.opacity(0.65)],
				startPoint: .leading,
				endPoint: .trailing
			)
		}

		// Semantic color ramp: grey -> yellow/orange -> green
		let colors: [Color]
		switch p {
		case 0..<0.10:
			colors = [Color.gray.opacity(0.55), Color.gray.opacity(0.35)]
		case 0.10..<nearFullThreshold:
			colors = [Color.yellow.opacity(0.85), Color.orange.opacity(0.70)]
		default:
			colors = [Color.green.opacity(0.90), Color.green.opacity(0.65)]
		}

		return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
	}

	private func startShimmerIfNeeded() {
		guard isActive else { return }
		shimmerPhase = 0
		withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
			shimmerPhase = 1
		}
	}
}

// MARK: - Example usage helper (your session function can call this)

extension DataFlowProgressBar {
	/// Convenience for your old call site:
	/// DataFlowProgressBar.fromSessionCount(session.data.count, maxSize: maxSessionDataSize, isActive: session.isRecording)
	public static func fromSessionCount(
		_ count: Int,
		maxSize: Int,
		isActive: Bool,
		label: String? = nil,
		tint: Color? = nil
	) -> DataFlowProgressBar {
		let p = min(Double(count) / Double(max(maxSize, 1)), 1.0)
		return DataFlowProgressBar(progress: p, isActive: isActive, label: label, tint: tint)
	}
}

// MARK: - Previews

#Preview("DataFlowProgressBar – Idle 32%") {
	ZStack {
		LinearGradient(
			colors: [Color.blue.opacity(0.12), Color(.systemBackground), Color.purple.opacity(0.10)],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		).ignoresSafeArea()

		VStack(spacing: 18) {
			DataFlowProgressBar(progress: 0.32, isActive: false)
				.padding(.horizontal)

			DataFlowProgressBar(progress: 0.62, isActive: true, label: "LIVE")
				.padding(.horizontal)

			DataFlowProgressBar(progress: 0.98, isActive: true, label: "98%")
				.padding(.horizontal)
		}
	}
}

#Preview("DataFlowProgressBar – Tinted") {
	ZStack {
		Color(.systemGroupedBackground).ignoresSafeArea()
		DataFlowProgressBar(progress: 0.54, isActive: true, label: "2.4 km", tint: .orange)
			.padding()
	}
}

