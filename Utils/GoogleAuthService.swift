import Foundation
import SwiftUI

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct GoogleSignInProfile {
    let id: String
    let email: String
    let name: String?
    let avatarURL: String?
    
    static func mock() -> GoogleSignInProfile {
        GoogleSignInProfile(
            id: "google_mock_\(UUID().uuidString)",
            email: "mockuser@gmail.com",
            name: "Google Kullanıcısı",
            avatarURL: "https://www.gravatar.com/avatar/00000000000000000000000000000000"
        )
    }
}

enum GoogleAuthError: LocalizedError {
    case missingPresentingController
    case sdkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .missingPresentingController:
            return "Google oturumu başlatmak için uygun bir pencere bulunamadı."
        case .sdkUnavailable:
            return "Google Sign-In SDK projeye eklenmedi."
        }
    }
}

final class GoogleAuthService {
    @MainActor
    func signIn() async throws -> GoogleSignInProfile {
#if canImport(GoogleSignIn)
        guard let presenter = UIApplication.shared.topViewController() else {
            throw GoogleAuthError.missingPresentingController
        }
        
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        let user = signInResult.user
        
        return GoogleSignInProfile(
            id: user.userID ?? UUID().uuidString,
            email: user.profile?.email ?? "",
            name: user.profile?.name,
            avatarURL: user.profile?.imageURL(withDimension: 120)?.absoluteString
        )
#else
        try await Task.sleep(nanoseconds: 400_000_000) // simulate network delay
        return GoogleSignInProfile.mock()
#endif
    }
}

#if canImport(UIKit)
private extension UIApplication {
    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseController: UIViewController?
        if let base {
            baseController = base
        } else {
            baseController = connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }
        
        if let nav = baseController as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        
        if let tab = baseController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        
        if let presented = baseController?.presentedViewController {
            return topViewController(base: presented)
        }
        
        return baseController
    }
}
#endif

