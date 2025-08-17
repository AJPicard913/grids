import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Space.createdAt, ascending: false)],
        animation: .default)
    private var spaces: FetchedResults<Space>
    
    @State private var selectedSpaceIndex = 0
    @State private var isEditMode = false
    @State private var showingSpaceSelector = false
    @State private var showingCreateGrid = false
    @State private var selectedTab = "home"
    
    // New state for size selection popover
    @State private var showingSizePopover = false
    @State private var gridForSizeSelection: Grid?
    
    private var currentSpace: Space? {
        guard !spaces.isEmpty else { return nil }
        return spaces[min(selectedSpaceIndex, spaces.count - 1)]
    }
    
    private var grids: [Grid] {
        guard let space = currentSpace else { return [] }
        let set = space.grids as? Set<Grid> ?? []
        return set.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    private func gridSize(for grid: Grid) -> BentoSize {
        // Use the size_ attribute from the Grid entity
        guard let sizeString = grid.size_ else {
            // Fallback logic if size_ is not set
            let itemCount = (grid.items as? Set<GridItem>)?.count ?? 0
            switch grid.type {
            case "media":
                return .large
            case "notes":
                return itemCount > 5 ? .medium : .small
            default:
                return itemCount > 10 ? .large : (itemCount > 3 ? .medium : .small)
            }
        }
        
        // Map the string value to BentoSize
        switch sizeString.lowercased() {
        case "small":
            return .small
        case "large":
            return .large
        default:
            return .medium
        }
    }
    
    // Replace the adaptiveGridView with a proper 2-column implementation
    private func adaptiveGridView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let gridWidth = (geometry.size.width - 40 - 16) / 2  // Accounting for padding and spacing
                let rows = createGridRows(grids: grids)
                
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    HStack(spacing: 16) {
                        ForEach(row.grids, id: \.id) { grid in
                            AdaptiveGridCard(grid: grid, isEditMode: isEditMode, width: row.type == .fullWidth ? (gridWidth * 2 + 16) : gridWidth)
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    gridForSizeSelection = grid
                                    showingSizePopover = true
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                                .modifier(ShakeEffect(animatableData: isEditMode ? 1 : 0))
                        }
                        
                        // Add spacer for single item rows
                        if row.grids.count == 1 && row.type != .fullWidth {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .animation(.spring(), value: isEditMode)
        .onTapGesture {
            if isEditMode {
                withAnimation(.spring()) {
                    isEditMode = false
                }
            }
        }
        .popover(isPresented: $showingSizePopover, attachmentAnchor: .point(.top), arrowEdge: .top) {
            if let grid = gridForSizeSelection {
                SizeSelectionPopover(grid: grid, onSave: { newSize in
                    updateGridSize(grid: grid, to: newSize)
                    showingSizePopover = false
                    gridForSizeSelection = nil
                }, onCancel: {
                    showingSizePopover = false
                    gridForSizeSelection = nil
                })
            }
        }
    }
    
    // Function to group grids into rows based on their sizes
    private func createGridRows(grids: [Grid]) -> [GridRow] {
        var rows: [GridRow] = []
        var currentRowGrids: [Grid] = []
        
        for grid in grids {
            let size = gridSize(for: grid)
            
            // If we have a large grid or the current row already has 2 items, start a new row
            if size == .large || currentRowGrids.count >= 2 {
                if !currentRowGrids.isEmpty {
                    rows.append(GridRow(grids: currentRowGrids, type: .normal))
                    currentRowGrids = []
                }
            }
            
            // Add large grids on their own row
            if size == .large {
                rows.append(GridRow(grids: [grid], type: .fullWidth))
            } else {
                currentRowGrids.append(grid)
            }
        }
        
        // Add remaining grids to the last row
        if !currentRowGrids.isEmpty {
            rows.append(GridRow(grids: currentRowGrids, type: .normal))
        }
        
        return rows
    }
    
    // Function to update grid size
    private func updateGridSize(grid: Grid, to size: BentoSize) {
        let sizeString: String
        switch size {
        case .small:
            sizeString = "small"
        case .medium:
            sizeString = "medium"
        case .large:
            sizeString = "large"
        }
        
        grid.size_ = sizeString
        grid.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving grid size: \(error)")
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main content
                if grids.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    adaptiveGridView(geometry: geometry)  // Use adaptive grid instead of bento
                }
                
                Spacer()
                
                // Custom Tab Bar
                if !grids.isEmpty {
                    customTabBar
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showingSpaceSelector) {
            SpaceSelectorView(spaces: Array(spaces), selectedIndex: $selectedSpaceIndex, showingCreateGrid: $showingCreateGrid)
        }
        .sheet(isPresented: $showingCreateGrid) {
            if let space = currentSpace {
                RichCreateGridView(space: space)
            }
        }
        .onAppear {
            if spaces.isEmpty {
                showingCreateGrid = true
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // App icon
            Image("AppIconUI")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            
            Spacer()
            
            // Space name and selector
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(currentSpace?.name ?? "No Grid")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    if spaces.count > 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text("Grid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Always show space selector when tapped, regardless of space count
                showingSpaceSelector = true
            }
            
            Spacer()
            
            // User avatar
            UserAvatarView()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    private var emptyStateView: some View {
        Button {
            showingCreateGrid = true
        } label: {
            VStack(alignment: .leading) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color("primaryPurple"))
                    .padding(.top, 8)
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap here to add your first Grid")
                        .font(.body)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color.primary)
                    
                    Text("Tap to select a widget to add to your dashboard.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: 168, height: 188)
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.8).opacity(0.3), radius: 40, x: 0, y: 5)
        }
    }
    
    private var customTabBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring()) { selectedTab = "home" }
                } label: {
                    Image(systemName: selectedTab == "home" ? "house.fill" : "house")
                        .font(.title2)
                        .foregroundColor(selectedTab == "home" ? Color("primaryPurple") : .gray)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color("backgroundPurple"))
                        .frame(width: 52, height: 40)
                        .opacity(selectedTab == "home" ? 1 : 0)
                )
                
                Button {
                    withAnimation(.spring()) { selectedTab = "notifications" }
                } label: {
                    Image(systemName: selectedTab == "notifications" ? "bell.fill" : "bell")
                        .font(.title2)
                        .foregroundColor(selectedTab == "notifications" ? Color("primaryPurple") : .gray)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color("backgroundPurple"))
                        .frame(width: 52, height: 40)
                        .opacity(selectedTab == "notifications" ? 1 : 0)
                )
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            
            Spacer()
            
            Button {
                showingCreateGrid = true
            } label: {
                Circle()
                    .fill(Color("primaryPurple"))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "plus").font(.title2).fontWeight(.semibold).foregroundColor(.white))
                    .shadow(color: Color("primaryPurple").opacity(0.3), radius: 15, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(), value: selectedTab)
    }
}


// MARK: - Supporting Views

struct UserAvatarView: View {
    var body: some View {
        Image(systemName: "person.circle.fill")
            .font(.title)
            .foregroundColor(.gray)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    }
}

enum BentoSize {
    case small, medium, large
}

struct BentoGridCard: View {
    let grid: Grid
    let isEditMode: Bool
    let size: BentoSize
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color("primaryPurple"))
            .frame(height: cardHeight)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(grid.title ?? "Untitled")
                            .font(.headline).fontWeight(.semibold).foregroundColor(.white)
                        Spacer()
                        if isEditMode {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundColor(.red)
                                .background(Color.white).clipShape(Circle())
                        }
                    }
                    GridPreviewContent(grid: grid, size: size)
                    Spacer()
                }.padding(16)
            )
            .shadow(color: Color("primaryPurple").opacity(0.2), radius: 15, x: 0, y: 5)
    }
    
    private var cardHeight: CGFloat {
        switch size {
        case .small: return 120
        case .medium: return 180
        case .large: return 240
        }
    }
}

struct GridPreviewContent: View {
    let grid: Grid
    let size: BentoSize
    
    private var items: [GridItem] {
        let set = grid.items as? Set<GridItem> ?? []
        return Array(set.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }.prefix(size == .large ? 6 : 3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack {
                    if item.type == "todo" {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    }
                    Text(item.content ?? "").lineLimit(1)
                }
                .font(.caption).foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let rotationAngle = sin(animatableData * .pi * 2) * 0.02
        let offsetX = cos(animatableData * .pi * 1.5) * 1
        let offsetY = sin(animatableData * .pi * 1.2) * 1
        
        let transform = CGAffineTransform(rotationAngle: rotationAngle).translatedBy(x: offsetX, y: offsetY)
        return ProjectionTransform(transform)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Data structures for grid rows
struct GridRow {
    let grids: [Grid]
    let type: RowType
}

enum RowType {
    case normal, fullWidth
}

// New views for the adaptive grid
struct AdaptiveGridRow: View {
    let grids: [Grid]
    let isEditMode: Bool
    let gridWidth: CGFloat
    let onSizeChange: (Grid) -> Void  // New parameter for size change callback
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(grids, id: \.id) { grid in
                AdaptiveGridCard(grid: grid, isEditMode: isEditMode, width: gridWidth)
                    .onLongPressGesture {
                        // Show size selection popover instead of toggling edit mode
                        onSizeChange(grid)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    .modifier(ShakeEffect(animatableData: isEditMode ? 1 : 0))
            }
            
            // Add spacing for single item in a row
            if grids.count == 1 {
                Spacer()
            }
        }
    }
}

struct AdaptiveGridCard: View {
    let grid: Grid
    let isEditMode: Bool
    let width: CGFloat
    
    private var size: BentoSize {
        // Calculate size based on the grid's size_ attribute
        guard let sizeString = grid.size_ else {
            let itemCount = (grid.items as? Set<GridItem>)?.count ?? 0
            switch grid.type {
            case "media":
                return .large
            case "notes":
                return itemCount > 5 ? .medium : .small
            default:
                return itemCount > 10 ? .large : (itemCount > 3 ? .medium : .small)
            }
        }
        
        switch sizeString.lowercased() {
        case "small":
            return .small
        case "large":
            return .large
        default:
            return .medium
        }
    }
    
    private var cardHeight: CGFloat {
        switch size {
        case .small: return 120
        case .medium: return 180
        case .large: return 200  // Slightly shorter for large in adaptive layout
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color("primaryPurple"))
            .frame(width: width, height: cardHeight)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(grid.title ?? "Untitled")
                            .font(.headline).fontWeight(.semibold).foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        if isEditMode {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundColor(.red)
                                .background(Color.white).clipShape(Circle())
                        }
                    }
                    GridPreviewContent(grid: grid, size: size)
                    Spacer()
                }.padding(16)
            )
            .shadow(color: Color("primaryPurple").opacity(0.2), radius: 15, x: 0, y: 5)
    }
}

// Compact size selection popover with icons
struct SizeSelectionPopover: View {
    let grid: Grid
    let onSave: (BentoSize) -> Void
    let onCancel: () -> Void
    
    @State private var selectedSize: BentoSize
    
    init(grid: Grid, onSave: @escaping (BentoSize) -> Void, onCancel: @escaping () -> Void) {
        self.grid = grid
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize with current size
        if let sizeString = grid.size_ {
            switch sizeString.lowercased() {
            case "small":
                _selectedSize = State(initialValue: .small)
            case "large":
                _selectedSize = State(initialValue: .large)
            default:
                _selectedSize = State(initialValue: .medium)
            }
        } else {
            _selectedSize = State(initialValue: .medium)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Grid Size")
                .font(.headline)
                .padding(.top, 16)
            
            HStack(spacing: 20) {
                SizeOptionButton(
                    title: "Small",
                    icon: "square",
                    size: .small,
                    isSelected: selectedSize == .small
                ) {
                    selectedSize = .small
                }
                
                SizeOptionButton(
                    title: "Medium",
                    icon: "rectangle",
                    size: .medium,
                    isSelected: selectedSize == .medium
                ) {
                    selectedSize = .medium
                }
                
                SizeOptionButton(
                    title: "Large",
                    icon: "rectangle.expand.vertical",
                    size: .large,
                    isSelected: selectedSize == .large
                ) {
                    selectedSize = .large
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Spacer()
                
                Button("Save") {
                    onSave(selectedSize)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color("primaryPurple"))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 300)
    }
}

struct SizeOptionButton: View {
    let title: String
    let icon: String
    let size: BentoSize
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? Color("primaryPurple") : .gray)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color("primaryPurple").opacity(0.1) : Color.clear)
                    )
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color("primaryPurple") : .gray)
            }
        }
    }
}