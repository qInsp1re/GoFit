import SwiftUI


@main

struct Sport_in_SamaraApp: App {
    
    @State private var isLoggedIn = UserDefaults.standard.bool(forKey: "isUserLoggedIn")
    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                SplashScreen()

            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}



