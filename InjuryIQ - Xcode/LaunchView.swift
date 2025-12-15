import SwiftUI

struct LaunchView: View {
    @Binding var isActive: Bool
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0

    // Helper to read version/build from Info.plist
    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }
    private var appBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
    }

    var body: some View {
        ZStack {
            // Use the AccentColor asset as the background
            Color(.teal)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Simple app title for the splash
                Text("InjuryIQ")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Your sport injury compa)nion")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 20)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        // Footer with version/build at bottom
        .overlay(
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("v\(appVersion)")
                    Text("(\(appBuild))")
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 12)
            }
            .padding(.horizontal), alignment: .bottom
        )
        .onAppear {
            print("[LaunchView] Appeared")
            // Animate in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }

            // After a short delay, hide the launch screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                print("[LaunchView] Transitioning to main app")
                withAnimation(.easeOut(duration: 0.3)) {
                    isActive = false
                }
            }
        }
    }
}

struct LaunchView_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var active = true
        var body: some View { LaunchView(isActive: $active) }
    }
    static var previews: some View {
        Wrapper()
            .previewDisplayName("LaunchView")
    }
}
