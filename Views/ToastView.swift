import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    let isDarkMode: Bool
    @Binding var isShowing: Bool
    
    enum ToastType {
        case success
        case error
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .success
            case .error: return .error
            case .info: return .primaryBlue
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(type.color)
            
            // Message
            Text(message)
                .font(.bodyMedium)
                .foregroundColor(isDarkMode ? .white : .textPrimary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Close button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .textTertiary : .textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isDarkMode ? 
                    Color(hex: "#1F2937") : 
                    Color.white
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    type.color.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(
            color: isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
            radius: 12,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
        .offset(y: isShowing ? 0 : -100)
        .opacity(isShowing ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShowing)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastView.ToastType
    let isDarkMode: Bool
    let duration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    ToastView(
                        message: message,
                        type: type,
                        isDarkMode: isDarkMode,
                        isShowing: $isShowing
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    
                    Spacer()
                }
                .zIndex(1000)
            }
        }
        .onChange(of: isShowing) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

extension View {
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        type: ToastView.ToastType = .success,
        isDarkMode: Bool = false,
        duration: Double = 3.0
    ) -> some View {
        modifier(ToastModifier(
            isShowing: isShowing,
            message: message,
            type: type,
            isDarkMode: isDarkMode,
            duration: duration
        ))
    }
}

#Preview {
    VStack {
        ToastView(
            message: "Varlık başarıyla eklendi!",
            type: .success,
            isDarkMode: false,
            isShowing: .constant(true)
        )
        
        ToastView(
            message: "Bir hata oluştu!",
            type: .error,
            isDarkMode: true,
            isShowing: .constant(true)
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
