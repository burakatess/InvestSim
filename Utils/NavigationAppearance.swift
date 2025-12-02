import SwiftUI

#if canImport(UIKit)
func configureNavigationAppearance(
    largeColor: UIColor = .white,
    inlineColor: UIColor? = nil
) {
    let inline = inlineColor ?? largeColor
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.largeTitleTextAttributes = [.foregroundColor: largeColor]
    appearance.titleTextAttributes = [.foregroundColor: inline]
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
    
    let navigationBar = UINavigationBar.appearance()
    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance
}
#else
func configureNavigationAppearance(
    largeColor: UIColor = .white,
    inlineColor: UIColor? = nil
) {}
#endif

