//
//  SportCardView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 29/12/2025.
//

import SwiftUI

struct MLCardView: View {
	
	let sport : Sports
	let session: Session
	let type : MLObjectType
	
	private let maxSessionDataSize: Int = 84000 // Adjust as needed
	
	@StateObject private var mlObject			: MLObject
	
	@State private var sliderValue		: Double = 3
	@State private var selectedDistance	: Int = 1
	@State private var distance 		= 5
	@State private var sets				= 3
	@State private var active			: Bool = false
	@State private var selectedDuration	: Int = 30
	@State private var duration 		= 30
	
	
	init(sport: Sports, session: Session, type: MLObjectType, previewMLObject: MLObject? = nil) {
		self.sport = sport
		self.session = session
		self.type = type
		let object = previewMLObject ?? MLCardView.loadOrCreateMLObject(for: type)
		_mlObject = StateObject(wrappedValue: object)
		_distance = State(initialValue: Int(object.distnace))
		_sets = State(initialValue: Int(object.sets))
		_active = State(initialValue: false)
		_duration = State(initialValue: Int(object.setDuration))
	}
	
	var body: some View {
		
		//let overallDim = session.state.isDimmed
		
		//debugLog(mlObject)
		
		VStack(spacing: 8) {
			
			HStack{
				Text(type.descriptor)
					.font(.title)
					.fontWeight(.semibold)
					.foregroundColor(.blue)
				
				Spacer()
					
				Image(systemName: type.iconName)
					.foregroundColor(Color.white)
					.font(.system(size: 20, weight: .bold))
					.frame(width: 44, height: 44)
					.background(Circle().fill(Color.blue))
					.shadow(radius: 2)
					
			}
			
			VStack() {
				ForEach(mlObject.sessions) { session in
					let percent = min(Double(session.data.count) / Double(maxSessionDataSize), 1.0)
					let active = percent > 0 && percent < 1.0
					DataFlowProgressBar(
						progress: percent,
						isActive: active,   // if you have this flag
						height: 40,
						label: "\(Int(percent * 100))%",
						tint: type.color
					)
					.accessibilityLabel("Session: \(Int(percent * 100))% complete")
				}
			}
			.padding(.horizontal, 40)
			.padding(.vertical)
			
			if !type.disableDistance {
				HStack{
					DistanceWheelSelector(selectedDistance: $distance, disabled: type.disableDistance)
					//Text("\(distance) km")
					Spacer()
				}
				.padding(.horizontal, 40)
				.padding(.vertical)
				.onChange(of: distance) { oldValue, newValue in
					mlObject.distnace = Double(newValue)
					try? mlObject.save()
				}
			}
			
			if mlObject.type == .stairs {
				HStack{
					SetsWheelSelector(selectedSet: $sets, disabled: !type.disableDistance)
					//Text("\(sets) sets(s)")
					Spacer()
				}
				.padding(.horizontal, 40)
				.padding(.vertical)
				.onChange(of: sets) { oldValue, newValue in
					mlObject.sets = newValue
					try? mlObject.save()
				}
			}
			
			if mlObject.type == .agility {
				HStack{
					DurationWheelSelector(selectedDuration: $duration, disabled: !type.disableDistance)
					//Text("\(sets) sets(s)")
					Spacer()
				}
				.padding(.horizontal, 40)
				.padding(.vertical)
				.onChange(of: duration) { oldValue, newValue in
					mlObject.setDuration = newValue
					try? mlObject.save()
				}
			}
			
			HStack() {
				
				Button(action: {
					self.active.toggle()
					mlObject.active = self.active
					try? mlObject.save()
				}) {
						Image(systemName: "sparkles")
							.foregroundColor(.white)
							.font(.system(size: 20, weight: .bold))
							.frame(width: 44, height: 44)
							.background(Circle().fill(mlObject.active ? Color.blue : Color.gray.opacity(0.3)))
							.shadow(radius: 2)
					}
					.buttonStyle(PlainButtonStyle())
					.rotatingDot(isActive: $mlObject.active)
				
				Text(mlObject.active ? "Training AI" : "Train AI?")
					.font(.caption)
				
				Spacer()
				
				Button(action: {
					let newObject = MLCardView.resetMLObject(for: type)
					mlObject.type = newObject.type
					mlObject.sessions = newObject.sessions
					mlObject.distnace = newObject.distnace
					mlObject.sets = newObject.sets
					mlObject.setDuration = newObject.setDuration
					mlObject.active = newObject.active
					distance = Int(newObject.distnace)
					sets = newObject.sets
					active = newObject.active
				}) {
					Label("Reset", systemImage: "arrow.clockwise")
						.foregroundColor(.white)
						.font(.system(size: 20, weight: .bold))
						.padding(.horizontal, 16)
						.padding(.vertical, 8)
						.background(Capsule().fill(Color.red))
						.shadow(radius: 2)
					}
					.buttonStyle(PlainButtonStyle())
				
				
			}
			.padding(.vertical)
			
			Text(type.explaination)
				.font(.footnote)
				.padding(.vertical)
			
		}
		.padding()
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color(.systemGray6))
				.overlay(
					RoundedRectangle(cornerRadius: 16)
						.stroke(Color(.systemGray4), lineWidth: 1)
				)
		)
		.shadow(color: Color(.black).opacity(0.05), radius: 4, x: 0, y: 2)
		.onChange(of: type) { oldType, newType in
			let newObject = MLCardView.loadOrCreateMLObject(for: newType)
			mlObject.type = newObject.type
			mlObject.sessions = newObject.sessions
			mlObject.distnace = newObject.distnace
			mlObject.sets = newObject.sets
			mlObject.setDuration = newObject.setDuration
			mlObject.active = newObject.active
		}
	}
	
	struct DistanceWheelSelector: View {
		@Binding var selectedDistance: Int
		let distances = Array(1...50)
		let disabled: Bool

		var body: some View {
			HStack{
				Text ("Distance:")
				Picker("Distance", selection: $selectedDistance) {
					ForEach(distances, id: \.self) { distance in
						Text("\(distance) km")
					}
				}
				.pickerStyle(.automatic)
				.disabled(disabled)
			}
		}
	}
	
	struct SetsWheelSelector: View {
		@Binding var selectedSet: Int
		let sets = Array(1...9)
		let disabled: Bool

		var body: some View {
			HStack{
				Text ("Sets:")
				Picker("Sets", selection: $selectedSet) {
					ForEach(sets, id: \.self) { set in
						Text("\(set) sets")
					}
				}
				.pickerStyle(.automatic)
				.disabled(disabled)
			}
		}
	}
	
	struct DurationWheelSelector: View {
		@Binding var selectedDuration: Int
		let durations = Array(9...90)
		let disabled: Bool

		var body: some View {
			HStack{
				Text ("Duration:")
				Picker("Duration", selection: $selectedDuration) {
					ForEach(durations, id: \.self) { duration in
						Text("\(duration) mins")
					}
				}
				.pickerStyle(.automatic)
				.disabled(disabled)
			}
		}
	}
	
	private func debugLog(_ object: Any) -> EmptyView {
		print("[MLCardView] mlObject : \(object)")
		return EmptyView()
	}
	
	private func formatDuration(_ t: TimeInterval) -> String {
		let s = max(0, Int(t))
		let h = s / 3600
		let m = (s % 3600) / 60
		let sec = s % 60
		return String(format: "%02d:%02d:%02d", h, m, sec)
	}
	
	static func loadOrCreateMLObject(for type: MLObjectType) -> MLObject {
			do {
				return try MLObject.load(type: type)
			} catch {
				let emptySessions = (0..<3).map { _ in MLSession(id: UUID(), data: Data()) }
				let newObject = MLObject(type: type, sessions: emptySessions)
				try? newObject.save()
				return newObject
			}
	}
	
	static func resetMLObject(for type: MLObjectType) -> MLObject {
		// Optionally delete the existing object if your model supports it
		try? MLObject.delete(type: type)
		let emptySessions = (0..<3).map { _ in MLSession(id: UUID(), data: Data()) }
		let newObject = MLObject(type: type, sessions: emptySessions, distance: 3.0, sets: 3)
		try? newObject.save()
		return newObject
	}
	
}

#Preview {
	let dummySessions = [
		MLSession(id: UUID(), data: Data(count: 84000)),   // 100% full
		MLSession(id: UUID(), data: Data(count: 37800)),   // 45% full (0.45 * 84000)
		MLSession(id: UUID(), data: Data())                // 0% full
	]
	let dummyMLObject = MLObject(type: .running, active: true, sessions: dummySessions)
	MLCardView(sport: Sports(), session: Session(), type: .agility, previewMLObject: dummyMLObject)
}
