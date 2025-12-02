import SwiftUI

enum PortfolioTab: String, CaseIterable {
    case assets = "Varlıklarım"
    case transactions = "İşlemler"
    
    var title: String {
        return rawValue
    }
}

struct PortfolioTabs: View {
    @Binding var selectedTab: PortfolioTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Color.white)
    }
}

#Preview {
    PortfolioTabs(selectedTab: .constant(.assets))
        .background(Color(.systemGroupedBackground))
}
