//
//  SingrayShape.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 17/12/2025.
//

import SwiftUI

/// A four-sided stingray-like shape:
/// - Top width wider than bottom (factor)
/// - Each edge is a curved arc
/// - Corners are smoothly rounded (C¹ continuity) via cubic blends


struct StingrayArcShape: Shape {
	// MARK: - Width & geometry
	var bottomWidthRatio: CGFloat = 0.60
	var topWidthFactor: CGFloat = 5.0
	var bottomPinchRatio: CGFloat = 0.12
	var verticalInsetRatio: CGFloat = 0.02
	
	// MARK: - Edge arc "sagitta" (positive = outward, negative = inward / concave)
	var topSagitta: CGFloat = 20
	var rightSagitta: CGFloat = 10
	var bottomSagitta: CGFloat = 3
	var leftSagitta: CGFloat = 10
	
	// MARK: - Corner smoothing
	/// Fraction of each edge to trim near corners (0.0...0.25).
	/// Typical: 0.08–0.12 for visible rounding; lower for subtle.
	var cornerTrim: CGFloat = 0.10
	
	/// Scale for blending cubic control handles (in points).
	/// This multiplies the tangent direction length at the trim points.
	/// Increase for "rounder" corner blends; decrease for tighter corners.
	var cornerBlendScale: CGFloat = 5
	
	func path(in rect: CGRect) -> Path {
		var path = Path()
		
		// Clamp inputs
		let bw = max(0.05, min(0.95, bottomWidthRatio))
		let tf = max(0.5, min(5.0, topWidthFactor))
		let pinch = max(0.0, min(0.5, bottomPinchRatio))
		let vPadRatio = max(0, min(0.2, verticalInsetRatio))
		let trim = max(0.0, min(0.25, cornerTrim))
		
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let w = rect.width
		let h = rect.height
		
		// Vertical padding
		let vPad = h * vPadRatio
		let topY = rect.minY + vPad
		let bottomY = rect.maxY - vPad
		
		// Top/bottom widths
		let bottomHalf = (w * bw) / 2.0
		var topHalf = bottomHalf * tf
		
		// Horizontal padding to avoid touching edges on extreme settings
		let hPad: CGFloat = w * 0.04
		topHalf = min(topHalf, (w - 2 * hPad) / 2.0)
		
		// Corner points (clockwise)
		let TL = CGPoint(x: center.x - topHalf,    y: topY)
		let TR = CGPoint(x: center.x + topHalf,    y: topY)
		let pinchAmount = pinch * w
		let BR = CGPoint(x: center.x + bottomHalf - pinchAmount, y: bottomY)
		let BL = CGPoint(x: center.x - bottomHalf + pinchAmount, y: bottomY)
		
		// === Edge helpers (quadratic Bézier for each edge) ===
		// Control points computed from sagitta using outward normal.
		func quadControl(from A: CGPoint, to B: CGPoint, sagitta s: CGFloat) -> CGPoint {
			let M = CGPoint(x: (A.x + B.x) / 2.0, y: (A.y + B.y) / 2.0)
			let chord = CGPoint(x: B.x - A.x, y: B.y - A.y)
			var n = CGPoint(x: chord.y, y: -chord.x) // perp
			let len = max(1e-6, hypot(n.x, n.y))
			n.x /= len; n.y /= len
			// Make outward point away from center (so positive s bulges outward)
			let toCenter = CGPoint(x: center.x - M.x, y: center.y - M.y)
			let dot = n.x * toCenter.x + n.y * toCenter.y
			let outwardSign: CGFloat = (dot < 0) ? 1 : -1
			let adjustedSagitta = s * outwardSign
			// For a quadratic Bézier, sagitta at midpoint is (control - M) dot n / 2
			// So control = M + 2 * s * n
			return CGPoint(x: M.x + 2 * adjustedSagitta * n.x,
						   y: M.y + 2 * adjustedSagitta * n.y)
		}
		
		// Evaluate a quadratic Bézier at t and its tangent vector (derivative)
		func quadPoint(_ A: CGPoint, _ C: CGPoint, _ B: CGPoint, _ t: CGFloat) -> CGPoint {
			let u = 1 - t
			return CGPoint(
				x: u*u*A.x + 2*u*t*C.x + t*t*B.x,
				y: u*u*A.y + 2*u*t*C.y + t*t*B.y
			)
		}
		func quadTangent(_ A: CGPoint, _ C: CGPoint, _ B: CGPoint, _ t: CGFloat) -> CGPoint {
			// derivative: 2(1 - t)(C - A) + 2t(B - C)
			let d1 = CGPoint(x: C.x - A.x, y: C.y - A.y)
			let d2 = CGPoint(x: B.x - C.x, y: B.y - C.y)
			return CGPoint(
				x: 2*(1 - t)*d1.x + 2*t*d2.x,
				y: 2*(1 - t)*d1.y + 2*t*d2.y
			)
		}
		// Convert a quadratic segment [t0..t1] to cubic Bézier (P0, P1, P2, P3)
		func quadSegmentToCubic(_ A: CGPoint, _ C: CGPoint, _ B: CGPoint,
								_ t0: CGFloat, _ t1: CGFloat)
		-> (CGPoint, CGPoint, CGPoint, CGPoint)
		{
			// Subdivide quadratic at t0 and t1:
			// Using De Casteljau: for any t, Q0=A, Q1=C, Q2=B
			// After subdivision from [t0..t1], we can derive the equivalent cubic control points.
			// Easier approach: compute endpoints and tangent directions at t0 and t1,
			// then approximate cubic with Hermite: P0=Pt0, P3=Pt1,
			// P1=P0 + (tangent0 * (Δt/3)), P2=P3 - (tangent1 * (Δt/3))
			// Scale tangents by normalized chord length for stability.
			let p0 = quadPoint(A, C, B, t0)
			let p3 = quadPoint(A, C, B, t1)
			let tan0 = quadTangent(A, C, B, t0)
			let tan1 = quadTangent(A, C, B, t1)
			let dt = t1 - t0
			// A simple scale: (dt / 3)
			let s = dt / 3.0
			let p1 = CGPoint(x: p0.x + s * tan0.x, y: p0.y + s * tan0.y)
			let p2 = CGPoint(x: p3.x - s * tan1.x, y: p3.y - s * tan1.y)
			return (p0, p1, p2, p3)
		}
		
		// Edge definitions (quadratic Béziers)
		let CT = quadControl(from: TL, to: TR, sagitta: topSagitta)
		let CR = quadControl(from: TR, to: BR, sagitta: rightSagitta)
		let CB = quadControl(from: BR, to: BL, sagitta: bottomSagitta)
		let CL = quadControl(from: BL, to: TL, sagitta: leftSagitta)
		
		// Trim fractions
		let t0 = trim
		let t1 = 1 - trim
		
		// Start at first edge’s start trim point
		let start = quadPoint(TL, CT, TR, t0)
		path.move(to: start)
		
		// Draw top edge middle segment (cubic derived from quad segment)
		do {
			let (_, p1, p2, p3) = quadSegmentToCubic(TL, CT, TR, t0, t1)
			path.addCurve(to: p3, control1: p1, control2: p2)
		}
		
		// Blend Top→Right (at TR corner) with a short cubic using trim tangents
		do {
			let endTop    = quadPoint(TL, CT, TR, t1)
			let tanTop    = quadTangent(TL, CT, TR, t1)
			let startRight = quadPoint(TR, CR, BR, t0)
			let tanRight   = quadTangent(TR, CR, BR, t0)
			
			// Cubic from endTop to startRight
			let c1 = CGPoint(x: endTop.x + cornerBlendScale * normalize(tanTop).x,
							 y: endTop.y + cornerBlendScale * normalize(tanTop).y)
			let c2 = CGPoint(x: startRight.x - cornerBlendScale * normalize(tanRight).x,
							 y: startRight.y - cornerBlendScale * normalize(tanRight).y)
			path.addCurve(to: startRight, control1: c1, control2: c2)
		}
		
		// Right edge middle segment
		do {
			let (_, p1, p2, p3) = quadSegmentToCubic(TR, CR, BR, t0, t1)
			path.addCurve(to: p3, control1: p1, control2: p2)
		}
		
		// Blend Right→Bottom (at BR corner)
		do {
			let endRight   = quadPoint(TR, CR, BR, t1)
			let tanRight   = quadTangent(TR, CR, BR, t1)
			let startBottom = quadPoint(BR, CB, BL, t0)
			let tanBottom   = quadTangent(BR, CB, BL, t0)
			
			let c1 = CGPoint(x: endRight.x + cornerBlendScale * normalize(tanRight).x,
							 y: endRight.y + cornerBlendScale * normalize(tanRight).y)
			let c2 = CGPoint(x: startBottom.x - cornerBlendScale * normalize(tanBottom).x,
							 y: startBottom.y - cornerBlendScale * normalize(tanBottom).y)
			path.addCurve(to: startBottom, control1: c1, control2: c2)
		}
		
		// Bottom edge middle segment
		do {
			let (_, p1, p2, p3) = quadSegmentToCubic(BR, CB, BL, t0, t1)
			path.addCurve(to: p3, control1: p1, control2: p2)
		}
		
		// Blend Bottom→Left (at BL corner)
		do {
			let endBottom = quadPoint(BR, CB, BL, t1)
			let tanBottom = quadTangent(BR, CB, BL, t1)
			let startLeft = quadPoint(BL, CL, TL, t0)
			let tanLeft   = quadTangent(BL, CL, TL, t0)
			
			let c1 = CGPoint(x: endBottom.x + cornerBlendScale * normalize(tanBottom).x,
							 y: endBottom.y + cornerBlendScale * normalize(tanBottom).y)
			let c2 = CGPoint(x: startLeft.x - cornerBlendScale * normalize(tanLeft).x,
							 y: startLeft.y - cornerBlendScale * normalize(tanLeft).y)
			path.addCurve(to: startLeft, control1: c1, control2: c2)
		}
		
		// Left edge middle segment
		do {
			let (_, p1, p2, p3) = quadSegmentToCubic(BL, CL, TL, t0, t1)
			path.addCurve(to: p3, control1: p1, control2: p2)
		}
		
		// Blend Left→Top (at TL corner) and close
		do {
			let endLeft  = quadPoint(BL, CL, TL, t1)
			let tanLeft  = quadTangent(BL, CL, TL, t1)
			let startTop = quadPoint(TL, CT, TR, t0)
			let tanTop   = quadTangent(TL, CT, TR, t0)
			
			let c1 = CGPoint(x: endLeft.x + cornerBlendScale * normalize(tanLeft).x,
							 y: endLeft.y + cornerBlendScale * normalize(tanLeft).y)
			let c2 = CGPoint(x: startTop.x - cornerBlendScale * normalize(tanTop).x,
							 y: startTop.y - cornerBlendScale * normalize(tanTop).y)
			path.addCurve(to: startTop, control1: c1, control2: c2)
		}
		
		path.closeSubpath()
		return path
	}
	
	// Normalize a vector (CGPoint) safely
	private func normalize(_ v: CGPoint) -> CGPoint {
		let L = max(1e-6, hypot(v.x, v.y))
		return CGPoint(x: v.x / L, y: v.y / L)
	}
	

	
	
	struct StingrayArcShape_Previews: PreviewProvider {
		static var previews: some View {
			HStack() {
				
				Spacer()
				
				StingrayArcShape()
					.fill(Color.green.opacity(0.8)) // fill color
				.overlay(
					StingrayArcShape()
					.stroke(.gray, lineWidth: 1)  // optional outline
				)
				.frame(width: 100, height: 70)
				.shadow(radius: 10)
				
				Spacer()
				
				StingrayArcShape()
					.fill(Color.green.opacity(0.8)) // fill color
				.overlay(
					StingrayArcShape()
					.stroke(.gray, lineWidth: 1)  // optional outline
				)
				.frame(width: 100, height: 70)
				.shadow(radius: 10)
				
				Spacer()
				
			}
			.previewLayout(.sizeThatFits)
		}
	}
}


