import SwiftUI

struct DZ4App_Previews: PreviewProvider {
    static var previews: some View {
        DZ4AppView()
            .environmentObject(AuthManager())
            .environmentObject(ThemeManager())
    }
}

// Wrapper View for Preview
struct DZ4AppView: View {
    @StateObject var authManager = AuthManager()
    @StateObject var themeManager = ThemeManager()
    
    @AppStorage("didCompleteOnboarding") var didCompleteOnboarding: Bool = false
    
    var body: some View {
        ZStack {
            if !didCompleteOnboarding {
                OnboardingRootView(didCompleteOnboarding: $didCompleteOnboarding)
                    .environmentObject(authManager)
                    .environmentObject(themeManager)
            } else if !authManager.isAuthorized {
                AuthRootView()
                    .environmentObject(authManager)
                    .environmentObject(themeManager)
            } else {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(themeManager)
            }
        }
        .environment(\.colorScheme, themeManager.selectedTheme == "dark" ? .dark : .light)
    }
}
