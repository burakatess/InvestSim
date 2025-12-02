import Foundation
import LocalAuthentication
import SwiftUI
import Combine

// MARK: - Biometric Authentication Manager
@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isAvailable: Bool = false
    @Published var biometryType: LABiometryType = .none
    @Published var isEnabled: Bool = false
    
    private let context = LAContext()
    
    private init() {
        _ = checkBiometricAvailability()
        loadEnabledState()
    }
    
    // MARK: - Public Methods
    
    @discardableResult
    func checkBiometricAvailability() -> Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        DispatchQueue.main.async {
            self.isAvailable = canEvaluate
            if canEvaluate {
                self.biometryType = self.context.biometryType
            }
        }
        
        return canEvaluate
    }
    
    func requestBiometricPermission() async -> Bool {
        guard isAvailable else {
            print("❌ Biometric authentication not available")
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Uygulamaya erişim için biyometrik kimlik doğrulama gerekli"
            )
            
            await MainActor.run {
                self.isEnabled = result
            }
            
            return result
        } catch {
            print("❌ Biometric authentication error: \(error.localizedDescription)")
            return false
        }
    }
    
    func authenticateUser() async -> Bool {
        guard isAvailable else {
            print("❌ Biometric authentication not available")
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Uygulamaya erişim için kimlik doğrulama gerekli"
            )
            return result
        } catch {
            print("❌ Biometric authentication error: \(error.localizedDescription)")
            return false
        }
    }
    
    func enableBiometricLock() async -> Bool {
        let success = await requestBiometricPermission()
        if success {
            isEnabled = true
            saveEnabledState()
        }
        return success
    }
    
    func disableBiometricLock() {
        isEnabled = false
        saveEnabledState()
    }
    
    func getBiometryTypeName() -> String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biyometrik Kimlik Doğrulama"
        @unknown default:
            return "Biyometrik Kimlik Doğrulama"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadEnabledState() {
        isEnabled = UserDefaults.standard.bool(forKey: "biometricLockEnabled")
    }
    
    private func saveEnabledState() {
        UserDefaults.standard.set(isEnabled, forKey: "biometricLockEnabled")
    }
}

// MARK: - Biometric Auth View Modifier
struct BiometricAuthModifier: ViewModifier {
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @State private var showingAuth = false
    @State private var isAuthenticated = false
    
    let onSuccess: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if biometricManager.isEnabled && !isAuthenticated {
                    showingAuth = true
                }
            }
            .sheet(isPresented: $showingAuth) {
                BiometricAuthView(
                    isPresented: $showingAuth,
                    onSuccess: {
                        isAuthenticated = true
                        onSuccess()
                    }
                )
            }
    }
}

// MARK: - Biometric Auth View
struct BiometricAuthView: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Icon
                Image(systemName: biometricManager.biometryType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 80))
                    .foregroundColor(.primaryBlue)
                
                // Title
                Text("Kimlik Doğrulama")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Description
                Text("\(biometricManager.getBiometryTypeName()) ile kimliğinizi doğrulayın")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Authenticate Button
                Button(action: authenticate) {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: biometricManager.biometryType == .faceID ? "faceid" : "touchid")
                        }
                        Text(isAuthenticating ? "Doğrulanıyor..." : "Kimlik Doğrula")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal)
                
                // Cancel Button
                Button("İptal") {
                    isPresented = false
                }
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            let success = await biometricManager.authenticateUser()
            
            await MainActor.run {
                isAuthenticating = false
                
                if success {
                    onSuccess()
                    isPresented = false
                } else {
                    errorMessage = "Kimlik doğrulama başarısız. Lütfen tekrar deneyin."
                }
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func biometricAuth(onSuccess: @escaping () -> Void) -> some View {
        modifier(BiometricAuthModifier(onSuccess: onSuccess))
    }
}
