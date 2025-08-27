import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Space.createdAt, ascending: false)],
        animation: .default
    )
    private var spaces: FetchedResults<Space>
    
    @State private var selectedSpaceIndex = 0
    @State private var isEditMode = false
    @State private var showingSpaceSelector = false
    @State private var showingCreateSpace = false
    @State private var showingCreateItem = false
    @State private var selectedTab = "home"
    @AppStorage("lastSelectedSpaceID") private var lastSelectedSpaceID: String = ""
    
    // Trigger view updates after size changes
    @State private var layoutTrigger = false
    
    // Namespace for matched geometry animations
    @Namespace private var ns
    
    private var currentSpace: Space? {
        guard !spaces.isEmpty else { return nil }
        return spaces[min(selectedSpaceIndex, spaces.count - 1)]
    }
    
    private var grids: [Grid] {
        guard let space = currentSpace else { return [] }
        let set = space.grids as? Set<Grid> ?? []
        return set.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
    
    // Stable ID for matchedGeometryEffect
    private func mgeID(for grid: Grid) -> String {
        if let id = grid.id?.uuidString { return id }
        return grid.objectID.uriRepresentation().absoluteString
    }
    
    // Sizes are user-controlled only. Default to .small if not set.
    private func gridSize(for grid: Grid) -> BentoSize {
        guard let sizeString = grid.size_?.lowercased() else { return .small }
        switch sizeString {
        case "small":  return .small
        case "medium": return .medium
        case "large":  return .large
        default:       return .small
        }
    }
    
    // Save size, then explicitly animate the layout change (with haptic)
    private func updateGridSizeWithRefresh(grid: Grid, to size: BentoSize) {
        let sizeString: String
        switch size {
        case .small:  sizeString = "small"
        case .medium: sizeString = "medium"
        case .large:  sizeString = "large"
        }
        
        // Haptic when the user commits to a new size
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        grid.size_ = sizeString
        grid.updatedAt = Date()
        
        do {
            try viewContext.save()
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25)) {
                layoutTrigger.toggle()
            }
        } catch {
            print("Error saving grid size: \(error)")
        }
    }

    private func persistCurrentSelection() {
        if let space = currentSpace, let id = space.id?.uuidString {
            lastSelectedSpaceID = id
        } else {
            lastSelectedSpaceID = ""
        }
    }

    private func restoreSelectionFromSavedID() {
        guard !spaces.isEmpty else { return }
        if let saved = UUID(uuidString: lastSelectedSpaceID),
           let idx = spaces.firstIndex(where: { $0.id == saved }) {
            if selectedSpaceIndex != idx {
                selectedSpaceIndex = idx
            }
        } else {
            // Default to first and persist it so future launches are stable
            selectedSpaceIndex = 0
            if let firstID = spaces.first?.id?.uuidString {
                lastSelectedSpaceID = firstID
            }
        }
    }
    
    // MARK: - Adaptive Grid
    private func adaptiveGridView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let horizontalPadding: CGFloat = 20
                let interItemSpacing: CGFloat = 16
                let fullWidth = geometry.size.width - (horizontalPadding * 2)
                let halfWidth = (fullWidth - interItemSpacing) / 2

                // Heights: small (1x1), medium (1x2), large (2x2 full width)
                let smallHeight: CGFloat = 120
                let mediumHeight: CGFloat = smallHeight * 2 + interItemSpacing
                let largeHeight: CGFloat = 260

                let sections = buildGridSections(from: grids)

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    switch section {
                    case .large(let g):
                        card(for: g, width: fullWidth, height: largeHeight)

                    case .flow(let items):
                        let columns = flowColumns(for: items, smallHeight: smallHeight, mediumHeight: mediumHeight, spacing: interItemSpacing)
                        // was: HStack(spacing: interItemSpacing) {
                        HStack(alignment: .top, spacing: interItemSpacing) {
                            LazyVStack(spacing: interItemSpacing) {
                                ForEach(columns.left, id: \.objectID) { g in
                                    let height = (gridSize(for: g) == .medium) ? mediumHeight : smallHeight
                                    card(for: g, width: halfWidth, height: height)
                                }
                            }
                            LazyVStack(spacing: interItemSpacing) {
                                ForEach(columns.right, id: \.objectID) { g in
                                    let height = (gridSize(for: g) == .medium) ? mediumHeight : smallHeight
                                    card(for: g, width: halfWidth, height: height)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(.top, 16)         
            .padding(.horizontal, 20)
        }
        .onChange(of: layoutTrigger) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onTapGesture {
            if isEditMode {
                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25)) {
                    isEditMode = false
                }
            }
        }
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: isEditMode)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: layoutTrigger)
    }

    private enum GridSection {
        case large(Grid)
        case flow([Grid]) // smalls + mediums (1x2)
    }

    private func buildGridSections(from items: [Grid]) -> [GridSection] {
        var sections: [GridSection] = []
        var buffer: [Grid] = []

        for g in items {
            switch gridSize(for: g) {
            case .large:
                if !buffer.isEmpty { sections.append(.flow(buffer)); buffer.removeAll() }
                sections.append(.large(g))
            case .medium, .small:
                buffer.append(g)
            }
        }
        if !buffer.isEmpty { sections.append(.flow(buffer)) }
        return sections
    }

    private func flowColumns(for items: [Grid], smallHeight: CGFloat, mediumHeight: CGFloat, spacing: CGFloat) -> (left: [Grid], right: [Grid]) {
        var left: [Grid] = []
        var right: [Grid] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for g in items {
            let h = (gridSize(for: g) == .medium) ? mediumHeight : smallHeight
            if leftHeight <= rightHeight {
                left.append(g)
                leftHeight += h + spacing
            } else {
                right.append(g)
                rightHeight += h + spacing
            }
        }
        return (left, right)
    }

    // Extracted builder: applies matched geometry + haptics + your existing context menu (unchanged)
    private func card(for g: Grid, width: CGFloat, height: CGFloat) -> some View {
        AdaptiveGridCard(
            grid: g,
            isEditMode: isEditMode,
            width: width,
            height: height
        )
        .matchedGeometryEffect(id: mgeID(for: g), in: ns)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .contextMenu {
            Button("Small (1x1)")  { updateGridSizeWithRefresh(grid: g, to: .small) }
            Button("Medium (1x2)") { updateGridSizeWithRefresh(grid: g, to: .medium) }
            Button("Large (2x2)")  { updateGridSizeWithRefresh(grid: g, to: .large) }
            Button("Delete Grid Widget", role: .destructive) { deleteGrid(g) }
            Button("Cancel", role: .cancel) { }
        }
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: width)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: height)
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity))
    }

    private func deleteGrid(_ grid: Grid) {
        withAnimation {
            viewContext.delete(grid)
            do {
                try viewContext.save()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                layoutTrigger.toggle()
            } catch {
                print("Error deleting grid: \(error)")
            }
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
                    adaptiveGridView(geometry: geometry)
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
            SpaceSelectorView(spaces: Array(spaces), selectedIndex: $selectedSpaceIndex, showingCreateSpace: $showingCreateSpace)
        }
        .fullScreenCover(isPresented: $showingCreateSpace) {
            CreateSpaceView(navigateAfterCreate: false)
        }
        .sheet(isPresented: $showingCreateItem) {
            if let space = currentSpace {
                RichCreateGridView(space: space)
            }
        }
        .onAppear {
            if spaces.isEmpty {
                showingCreateSpace = true
            } else {
                restoreSelectionFromSavedID()
            }
        }
        .onChange(of: selectedSpaceIndex) {
            persistCurrentSelection()
        }
        .onChange(of: spaces.map { $0.id?.uuidString ?? $0.objectID.uriRepresentation().absoluteString }) { _, _ in
            restoreSelectionFromSavedID()
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
            showingCreateItem = true
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
                showingCreateItem = true
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
    
    private var backgroundColor: Color {
        switch size {
        case .small:  return Color(red: 0.2902, green: 0.2118, blue: 0.7059) // #4A36B4
        case .medium: return Color(red: 0.6392, green: 0.5882, blue: 1.0000) // #A396FF
        case .large:  return Color(red: 0.0824, green: 0.0471, blue: 0.2471) // #150C3F
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(backgroundColor)
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
            .shadow(color: backgroundColor.opacity(0.2), radius: 15, x: 0, y: 5)
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

// MARK: - AdaptiveGridCard (smoothed + per-card haptic on layout)
struct AdaptiveGridCard: View {
    let grid: Grid
    let isEditMode: Bool
    let width: CGFloat
    let height: CGFloat
    
    private var size: BentoSize {
        // Only reflect user-chosen size; default to .small
        switch grid.size_?.lowercased() {
        case "medium": return .medium
        case "large":  return .large
        default:       return .small
        }
    }
    
    private var backgroundColor: Color {
        switch size {
        case .small:  return Color(red: 0.2902, green: 0.2118, blue: 0.7059) // #4A36B4
        case .medium: return Color(red: 0.6392, green: 0.5882, blue: 1.0000) // #A396FF
        case .large:  return Color(red: 0.0824, green: 0.0471, blue: 0.2471) // #150C3F
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(backgroundColor)
            .frame(width: width, height: height)
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
                }
                .padding(16)
            )
            .shadow(color: backgroundColor.opacity(0.2), radius: 15, x: 0, y: 5)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: width)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.25), value: height)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity))
            .onChange(of: grid.size_ ?? "") { _ in
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
    }
}