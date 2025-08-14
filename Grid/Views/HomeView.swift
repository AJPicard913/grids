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
    
    private var currentSpace: Space? {
        guard !spaces.isEmpty else { return nil }
        return spaces[min(selectedSpaceIndex, spaces.count - 1)]
    }
    
    private var grids: [Grid] {
        guard let space = currentSpace else { return [] }
        let set = space.grids as? Set<Grid> ?? []
        return set.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
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
                    bentoGridView(geometry: geometry)
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
    
    private func bentoGridView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(grids.chunked(into: 2)), id: \.first?.id) { rowGrids in
                    HStack(spacing: 16) {
                        ForEach(rowGrids, id: \.id) { grid in
                            BentoGridCard(grid: grid, isEditMode: isEditMode, size: gridSize(for: grid))
                                .onLongPressGesture {
                                    withAnimation(.spring()) {
                                        isEditMode.toggle()
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                                .modifier(ShakeEffect(animatableData: isEditMode ? 1 : 0))
                        }
                        if rowGrids.count == 1 {
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
    }
    
    private func gridSize(for grid: Grid) -> BentoSize {
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