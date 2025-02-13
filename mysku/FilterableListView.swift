import SwiftUI

struct FilterableListView<Item: Identifiable, ItemContent: View>: View {
    let items: [Item]
    let searchPlaceholder: String
    @Binding var searchText: String
    let content: (Item) -> ItemContent
    
    init(
        items: [Item],
        searchPlaceholder: String,
        searchText: Binding<String>,
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) {
        self.items = items
        self.searchPlaceholder = searchPlaceholder
        self._searchText = searchText
        self.content = content
    }
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        // This is a placeholder filter - you'll need to implement specific filtering logic
        // based on your Item type in the parent view
        return items
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(searchPlaceholder, text: $searchText)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredItems) { item in
                        content(item)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
} 