import SwiftUI

struct ModernButton: View {
    let title: String
    let style: ModernButtonStyle
    let size: ButtonSize
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        style: ModernButtonStyle = .primary,
        size: ButtonSize = .medium,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: size.fontSize, weight: .semibold))
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(style.backgroundColor)
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
        }
        .disabled(isLoading)
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    
    static let primary = ModernButtonStyle(
        backgroundColor: .primaryBlue,
        foregroundColor: .white,
        borderColor: .clear,
        borderWidth: 0
    )
    
    static let secondary = ModernButtonStyle(
        backgroundColor: .clear,
        foregroundColor: .primaryBlue,
        borderColor: .primaryBlue,
        borderWidth: 1
    )
    
    static let success = ModernButtonStyle(
        backgroundColor: .success,
        foregroundColor: .white,
        borderColor: .clear,
        borderWidth: 0
    )
    
    static let danger = ModernButtonStyle(
        backgroundColor: .error,
        foregroundColor: .white,
        borderColor: .clear,
        borderWidth: 0
    )
    
    static let ghost = ModernButtonStyle(
        backgroundColor: .clear,
        foregroundColor: .adaptiveLabel,
        borderColor: .clear,
        borderWidth: 0
    )
}

struct ButtonSize {
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    let iconSize: CGFloat
    
    static let small = ButtonSize(
        fontSize: 14,
        horizontalPadding: 12,
        verticalPadding: 8,
        cornerRadius: 8,
        iconSize: 14
    )
    
    static let medium = ButtonSize(
        fontSize: 16,
        horizontalPadding: 16,
        verticalPadding: 12,
        cornerRadius: 10,
        iconSize: 16
    )
    
    static let large = ButtonSize(
        fontSize: 18,
        horizontalPadding: 20,
        verticalPadding: 16,
        cornerRadius: 12,
        iconSize: 18
    )
}

// Specialized Button Types
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.primaryBlue)
                .cornerRadius(28)
                .shadow(.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IconButton: View {
    let icon: String
    let style: ModernButtonStyle
    let size: ButtonSize
    let action: () -> Void
    
    init(
        icon: String,
        style: ModernButtonStyle = .ghost,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(style.foregroundColor)
                .frame(width: size.verticalPadding * 2, height: size.verticalPadding * 2)
                .background(style.backgroundColor)
                .cornerRadius(size.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        ModernButton("Primary Button", style: .primary, action: {})
        ModernButton("Secondary Button", style: .secondary, action: {})
        ModernButton("Success Button", style: .success, action: {})
        ModernButton("Danger Button", style: .danger, action: {})
        ModernButton("With Icon", style: .primary, icon: "plus", action: {})
        ModernButton("Loading", style: .primary, isLoading: true, action: {})
        
        HStack {
            IconButton(icon: "heart", action: {})
            IconButton(icon: "star", style: .secondary, action: {})
            FloatingActionButton(icon: "plus", action: {})
        }
    }
    .padding()
    .background(Color.adaptiveBackground)
}
