//
//  SessionStatusIndicator.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 24/12/2025.
//

import SwiftUI

// MARK: - Public types

//public struct SessionActivity: Hashable {
//	public let title: String
//	public let systemImage: String

//	public init(title: String, systemImage: String) {
//		self.title = title
//		self.systemImage = systemImage
//	}

//	public static let hike		= SessionActivity(title: "Hike", systemImage: "figure.hiking")
//	public static let running	= SessionActivity(title: "Run", systemImage: "figure.run")
//	public static let cycling	= SessionActivity(title: "Cycling", systemImage: "figure.outdoor.cycle")
//	public static let racket	= SessionActivity(title: "Racket", systemImage: "figure.tennis")
//}

// MARK: - SessionStatusIndicator (Dual fatigue halves)

public struct SessionStatusIndicator: View {
	/// Fatigue values as percentages (0...100). If nil => no signal provided.
	public let leftFatiguePct: Double?
	public let rightFatiguePct: Double?

	/// Connection flags: if false => render grey placeholder half (even if value present).
	public let leftConnected: Bool
	public let rightConnected: Bool

	public let duration: TimeInterval
	public let distance: Double
	public let speed: Double
	public let sessionState: SessionState
	public let activity: ActivityType

	/// Optional label under duration (e.g. "Mild Fatigue")
	public let subtitle: String?

	// Styling knobs
	public var ringLineWidth: CGFloat = 16
	public var ringInset: CGFloat = 14
	public var segmentCountPerHalf: Int = 18   // per half
	public var segmentGapFraction: CGFloat = 0.30

	// Internal animation states (minimal)
	@State private var breathe: Bool = false
	@State private var sweepPhase: CGFloat = 0

	public init(
		leftFatiguePct: Double?,
		rightFatiguePct: Double?,
		leftConnected: Bool,
		rightConnected: Bool,
		duration: TimeInterval,
		distance: Double,
		speed: Double,
		sessionState: SessionState,
		activity: ActivityType,
		subtitle: String? = nil
	) {
		self.leftFatiguePct = leftFatiguePct
		self.rightFatiguePct = rightFatiguePct
		self.leftConnected = leftConnected
		self.rightConnected = rightConnected
		self.duration = duration
		self.distance = distance
		self.speed = speed
		self.sessionState = sessionState
		self.activity = activity
		self.subtitle = subtitle
	}

	public var body: some View {
		GeometryReader { geo in
			let size = min(geo.size.width, geo.size.height)
			let ringRect = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: ringInset, dy: ringInset)
			let overallDim = sessionState.isDimmed

			ZStack {
				// Base
				Circle()
					.fill(.ultraThinMaterial)
					.overlay(
						Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
					)
					.shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)

				// Background segmented halves
				HalfSegmentedRingShape(
					side: .left,
					segments: segmentCountPerHalf,
					gapFraction: segmentGapFraction
				)
				.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
				.foregroundStyle(Color.white.opacity(0.12))
				.frame(width: ringRect.width, height: ringRect.height)

				HalfSegmentedRingShape(
					side: .right,
					segments: segmentCountPerHalf,
					gapFraction: segmentGapFraction
				)
				.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
				.foregroundStyle(Color.white.opacity(0.12))
				.frame(width: ringRect.width, height: ringRect.height)

				// LEFT half: placeholder or progress
				Group {
					if leftShowsSignal {
						HalfProgressArcShape(side: .left, progress: effectiveProgress(leftProgress))
							.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
							.foregroundStyle(halfFatigueGradient) // bottom green -> top red
					} else {
						HalfSegmentedRingShape(side: .left, segments: segmentCountPerHalf, gapFraction: segmentGapFraction)
							.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
							.foregroundStyle(Color.gray.opacity(0.28))
					}
				}
				.frame(width: ringRect.width, height: ringRect.height)
				.opacity(overallDim ? 0.30 : 1.0)
				.animation(.easeInOut(duration: 0.35), value: leftProgress)

				// RIGHT half: placeholder or progress
				Group {
					if rightShowsSignal {
						HalfProgressArcShape(side: .right, progress: effectiveProgress(rightProgress))
							.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
							.foregroundStyle(halfFatigueGradient)
					} else {
						HalfSegmentedRingShape(side: .right, segments: segmentCountPerHalf, gapFraction: segmentGapFraction)
							.stroke(style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
							.foregroundStyle(Color.gray.opacity(0.28))
					}
				}
				.frame(width: ringRect.width, height: ringRect.height)
				.opacity(overallDim ? 0.30 : 1.0)
				.animation(.easeInOut(duration: 0.35), value: rightProgress)

				// Thin state ring cue
				Circle()
					.strokeBorder(sessionState.accent.opacity(overallDim ? 0.18 : 0.38), lineWidth: 2)
					.padding(ringInset + ringLineWidth / 2)

				// Minimal running “breath”
				if sessionState.isAnimated {
					Circle()
						.strokeBorder(sessionState.accent.opacity(breathe ? 0.10 : 0.22), lineWidth: 10)
						.scaleEffect(breathe ? 1.08 : 0.985)
						.padding(ringInset + ringLineWidth / 2 - 6)
						.animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)
				}

				// Optional small dots at bottom for side identity (subtle)
				HStack(spacing: 12) {
					Circle().fill(self.leftConnected ? Color.blue : Color.gray.opacity(0.35))
						.frame(width: 15, height: 15)
					Circle().fill(self.rightConnected ? Color.blue : Color.gray.opacity(0.35))
						.frame(width: 15, height: 15)
				}
				.offset(y: (size / 2) - ringInset - ringLineWidth - 10)

				// Center content
				VStack(spacing: 10) {
					ZStack {
						Circle()
							.fill(sessionState.accent.opacity(overallDim ? 0.10 : 0.16))
						Image(systemName: activity.icon)
							.font(.system(size: 24, weight: .semibold, design: .rounded))
							.foregroundStyle(overallDim ? .secondary : sessionState.accent)
					}
					.frame(width: 54, height: 54)

					Text(sessionState.rawValue)
						.font(.caption)
						.fontWeight(.semibold)
						.tracking(1.1)
						.foregroundStyle(overallDim ? .secondary : sessionState.accent)

					Text(formatDuration(duration))
						.font(.system(size: 40, weight: .bold, design: .rounded))
						.minimumScaleFactor(0.7)
						.foregroundStyle(overallDim ? .secondary : .primary)
					
					HStack(){
						//Text(String(format: "%dkm", Int(distance)))
						Text(String(format: "%0.1fkm", distance))
							.frame(width: 70, alignment: .trailing)
						//Text( speed > 0 ? String(format: "%.2fkmph", speed) : "-kmph")
						Text(speed > 0 ? String(format: "%dkmph", Int(speed)) : "-- kmph")
							.frame(width: 80, alignment: .leading)
					}
					.font(.system(size: 16, weight: .bold, design: .rounded))
					.minimumScaleFactor(0.7)
					.foregroundStyle(overallDim ? .secondary : .primary)
					.opacity(0.7)
					
					
					if let subtitle {
						Divider()
							.frame(maxWidth: 170)
							.opacity(0.35)

						Text(subtitle)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
				.padding(.horizontal, 16)

				// Optional side percentages (easy to remove if you prefer no text)
				HStack {
					SidePctLabel(text: leftShowsSignal ? "\(Int(round(leftProgress * 100)))%" : "—", enabled: leftShowsSignal)
					Spacer()
					SidePctLabel(text: rightShowsSignal ? "\(Int(round(rightProgress * 100)))%" : "—", enabled: rightShowsSignal)
				}
				.padding(.horizontal, -15)
				.offset(y: 120)
				.opacity(0.65)
			}
			.frame(width: size, height: size)
			.onAppear { configureAnimation() }
			.onChange(of: sessionState) { _, _ in configureAnimation() }
		}
		.aspectRatio(1, contentMode: .fit)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityText)
	}

	// MARK: - Derived values

	private var leftShowsSignal: Bool {
		leftConnected && (leftFatiguePct != nil)
	}

	private var rightShowsSignal: Bool {
		rightConnected && (rightFatiguePct != nil)
	}

	private var leftProgress: Double {
		guard let v = leftFatiguePct else { return 0 }
		return min(max(v / 100.0, 0), 1)
	}

	private var rightProgress: Double {
		guard let v = rightFatiguePct else { return 0 }
		return min(max(v / 100.0, 0), 1)
	}

	/// Subtle wobble only when running.
	private func effectiveProgress(_ base: Double) -> Double {
		guard sessionState.isAnimated else { return base }
		let wobble = Double(sin(Double(sweepPhase) * .pi * 2)) * 0.006
		return min(max(base + wobble, 0), 1)
	}

	/// Same gradient for each half: green at bottom rising to red at top of the arc.
	private var halfFatigueGradient: LinearGradient {
		LinearGradient(
			colors: [.green, .yellow, .orange, .red],
			startPoint: .bottom,
			endPoint: .top
		)
	}

	private var accessibilityText: String {
		let l = leftShowsSignal ? "\(Int(round(leftProgress * 100))) percent" : "not available"
		let r = rightShowsSignal ? "\(Int(round(rightProgress * 100))) percent" : "not available"
		return "\(activity.descriptor). \(sessionState.rawValue). Duration \(formatDuration(duration)). Left fatigue \(l). Right fatigue \(r)."
	}

	// MARK: - Animation control

	private func configureAnimation() {
		breathe = false
		sweepPhase = 0

		guard sessionState.isAnimated else { return }

		breathe = true
		withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
			sweepPhase = 1
		}
	}

	// MARK: - Formatting

	private func formatDuration(_ t: TimeInterval) -> String {
		let s = max(0, Int(t))
		let h = s / 3600
		let m = (s % 3600) / 60
		let sec = s % 60
		return String(format: "%02d:%02d:%02d", h, m, sec)
	}
}

// MARK: - Supporting Views

private struct SidePctLabel: View {
	let text: String
	let enabled: Bool

	var body: some View {
		Text(text)
			.font(.title3.weight(.semibold))
			.foregroundStyle(enabled ? .primary : .secondary)
	}
}

// MARK: - Composable Shapes (split ring)

// Which side of the split ring a shape draws
enum RingSide { case left, right }

/// Draws a segmented half-ring (left or right) around the circle.
struct HalfSegmentedRingShape: Shape {
	let side: RingSide
	let segments: Int
	/// 0...1 higher means larger gaps
	let gapFraction: CGFloat

	func path(in rect: CGRect) -> Path {
		var p = Path()
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let radius = min(rect.width, rect.height) / 2

		// Each half spans 180 degrees (π radians), from bottom to top.
		// Left: bottom(90°) -> top(270°) going counter-clockwise
		// Right: bottom(90°) -> top(-90° / 270°) going clockwise direction if ccw
		// We'll draw both halves counter-clockwise using start/end angles:
		// Right half: start at 90° to -90° (i.e., 90° to 270° but *the other side*) is tricky.
		// Instead: define explicit radians for each half as [start, end] on the circle in CCW direction.
		//
		// Using standard unit circle with 0 at east, CCW positive:
		// Top = -90° (or 270°), Bottom = 90°, Left = 180°, Right = 0°.
		//
		// Left half CCW: from bottom (90°) -> top (270°) spans the left side.
		// Right half CCW: from top (270°) -> bottom (450°) spans the right side.
		// We'll represent angles in radians accordingly.

		let start: CGFloat
		let end: CGFloat

		switch side {
		case .left:
			start = .pi / 2            // 90°
			end = .pi * 3 / 2          // 270°
		case .right:
			start = .pi * 3 / 2        // 270°
			end = .pi * 5 / 2          // 450° (wraps)
		}

		let total = CGFloat(max(1, segments))
		let span = end - start
		let segAngle = span / total
		let gap = segAngle * min(max(gapFraction, 0), 0.9)
		let draw = segAngle - gap

		for i in 0..<segments {
			let a0 = start + CGFloat(i) * segAngle + gap / 2
			let a1 = a0 + draw
			p.addArc(center: center, radius: radius, startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)), clockwise: false)
		}

		return p
	}
}

/// Draws a progress arc for a given half, from bottom rising towards top.
struct HalfProgressArcShape: Shape {
	let side: RingSide
	/// 0...1 across the half arc (bottom -> top)
	var progress: Double

	var animatableData: Double {
		get { progress }
		set { progress = newValue }
	}

	func path(in rect: CGRect) -> Path {
		var p = Path()
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let radius = min(rect.width, rect.height) / 2

		let clamped = max(0, min(1, progress))

		// Half span is π radians (180°)
		let start: CGFloat
		switch side {
		case .left:
			start = .pi / 2            // bottom
		case .right:
			start = .pi / 2            // bottom also, but we need to draw on right side: use start at 90° and go *clockwise* to -90°.
		}

		if side == .left {
			// Left: bottom (90°) -> top (270°) CCW
			let end = (.pi / 2) + CGFloat(clamped) * .pi
			p.addArc(center: center, radius: radius,
					 startAngle: .radians(Double(start)),
					 endAngle: .radians(Double(end)),
					 clockwise: false)
		} else {
			// Right: bottom (90°) -> top (-90°) clockwise.
			// SwiftUI arc uses clockwise Bool, so go clockwise from 90° down to (90° - progress*180°)
			let end = (.pi / 2) - CGFloat(clamped) * .pi
			p.addArc(center: center, radius: radius,
					 startAngle: .radians(Double(start)),
					 endAngle: .radians(Double(end)),
					 clockwise: true)
		}

		return p
	}
}

// MARK: - Previews

#Preview("Both Connected - Running") {
	VStack(spacing: 16) {
		SessionStatusIndicator(
			leftFatiguePct: 56,
			rightFatiguePct: 68,
			leftConnected: true,
			rightConnected: true,
			duration: 42 * 60 + 30,
			distance: 2.5,
			speed: 0.7,
			sessionState: .running,
			activity: .hiking,
			subtitle: "Mild Fatigue"
		)
		.frame(width: 320)

		Text("Both connected • running")
			.foregroundStyle(.secondary)
	}
	.padding()
	//.background(
	//	LinearGradient(colors: [Color.blue.opacity(0.10), Color(.systemBackground)],
	//				   startPoint: .topLeading, endPoint: .bottomTrailing)
	//)
}

#Preview("One Connected - Paused") {
	SessionStatusIndicator(
		leftFatiguePct: 34,
		rightFatiguePct: nil,
		leftConnected: true,
		rightConnected: false,
		duration: 18 * 60 + 12,
		distance: 100,
		speed: 99,
		sessionState: .paused,
		activity: .running,
		subtitle: "Normal"
	)
	.frame(width: 320)
	.padding()
	//.background(Color(.systemGroupedBackground))
}

#Preview("Both Disconnected - Idle") {
	SessionStatusIndicator(
		leftFatiguePct: nil,
		rightFatiguePct: nil,
		leftConnected: false,
		rightConnected: false,
		duration: 0,
		distance: 0.5,
		speed: 4.8,
		sessionState: .stopped,
		activity: .hiking,
		subtitle: nil
	)
	.frame(width: 320)
	.padding()
	//.background(Color(.systemGroupedBackground))
}

#Preview("Stopped - One Missing Value") {
	SessionStatusIndicator(
		leftFatiguePct: 82,
		rightFatiguePct: nil,
		leftConnected: true,
		rightConnected: true, // connected but no value => placeholder (per your rule)
		duration: 65 * 60 + 4,
		distance: 7.8,
		speed: 4.8,
		sessionState: .stopped,
		activity: .hiking,
		subtitle: "High Fatigue"
	)
	.frame(width: 320)
	.padding()
	//.background(Color(.systemGroupedBackground))
}
