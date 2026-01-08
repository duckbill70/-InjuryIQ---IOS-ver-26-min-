//
//  AITrainingView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 29/12/2025.
//

import SwiftUI
import UIKit

struct niuAITrainingView: View {
	@EnvironmentObject private var ble: BLEManager
	@Environment(\.modelContext) private var modelContext
	@Environment(Session.self) private var session
	@Bindable var sports: Sports
	
	@State private var selectedTab: MLObjectType = .running
	
	let tabs: [MLObjectType] = MLObjectType.allCases
	
	init(sports: Sports) {
		self.sports = sports
		UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.label
		UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray4
	}
	
    var body: some View {
		
		VStack() {
			
			//Text("This screen displays a series of training cards, each representing a different activity type (such as running, walking, agility, cycling, or stairs). Each card provides details and options specific to the selected activity, helping you review and manage your training sessions.")
			//	.font(.caption)
			//	.multilineTextAlignment(.leading)
			//	.padding(.top)
			
			//HStack(spacing: 12) {
			//				ForEach(tabs, id: \.self) { type in
			//					Button(action: { selectedTab = type }) {
			//						VStack(spacing: 0) {
			//							Image(systemName: type.iconName)
			//							Text(type.descriptor)
			//								.font(.caption2)
			//						}
			//						.foregroundColor(selectedTab == type ? .accentColor : .secondary)
			//						.frame(minWidth: 50, minHeight: 40)
			//						.padding(.vertical, 8)
			//						.padding(.horizontal, 5)
			//						.background(
			//							Capsule()
			//								.fill(selectedTab == type ? Color(.systemGray5) : Color.clear)
			//						)
			//					}
			//					.buttonStyle(PlainButtonStyle())
			//				}
			//			}
			//			.background(
			//				Capsule()
			//					.stroke(Color(.systemGray4), lineWidth: 1)
			//					.padding(-4)
			//			)
			//			.padding(.top)
		//
			//MLCardView(sport: sports, session: session, type: selectedTab)
			
			//Spacer()
			
			TabView {
				MLCardView(sport: sports, session: session, type: .running)
					.tabItem { Label("Running", systemImage: "figure.run") }
				MLCardView(sport: sports, session: session, type: .walking)
					.tabItem { Label("Walking", systemImage: "figure.walk") }
				MLCardView(sport: sports, session: session, type: .agility)
					.tabItem { Label("Agility", systemImage: "bolt") }
				MLCardView(sport: sports, session: session, type: .cycling)
					.tabItem { Label("Cycling", systemImage: "bicycle") }
				MLCardView(sport: sports, session: session, type: .stairs)
					.tabItem { Label("Stairs", systemImage: "stairs") }
			}
			.tabViewStyle(.automatic)
			//.frame(height: 200) // Adjust height as needed
			//.padding(.bottom, 40)
			
			//Spacer()
			
		}
		.padding()
    }
	
}

#Preview {
	
	@Previewable @State var sports = Sports()
	@Previewable @State var session = Session()
	
    niuAITrainingView(sports: sports)
		.environmentObject(BLEManager.shared)
		.environment(session)
	
}

