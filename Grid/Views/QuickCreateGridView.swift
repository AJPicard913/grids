import SwiftUI
import CoreData

struct QuickCreateGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var space: Space

    @State private var gridTitle: String = ""
    @State private var selectedSize: SizeOption = .small
    @State private var showingInviteSheet = false
    @State private var showingShareSheet = false

    enum SizeOption: String, CaseIterable, Identifiable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        var id: String { rawValue }
        var coreDataValue: String {
            switch self {
            case .small: return "small"
            case .medium: return "medium"
            case .large: return "large"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("Name Grid")) {
                        TextField("Grid name", text: $gridTitle)
                            .textInputAutocapitalization(.words)
                    }

                    Section(header: Text("Options")) {
                        Picker("Size", selection: $selectedSize) {
                            ForEach(SizeOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section(header: Text("Invite")) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Invite via Link", systemImage: "link")
                        }

                        Button {
                            showingInviteSheet = true
                        } label: {
                            Label("Invite Members…", systemImage: "person.badge.plus")
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(action: createGrid) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.3, green: 0.2, blue: 0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color("primaryPurple").opacity(0.25), radius: 20, x: 0, y: 8)
                    }
                    .disabled(gridTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("New Grid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteMemberView(space: space)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [inviteLink()])
        }
    }

    private func createGrid() {
        let title = gridTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation {
            let newGrid = Grid(context: viewContext)
            newGrid.id = UUID()
            newGrid.title = title
            newGrid.createdAt = Date()
            newGrid.updatedAt = Date()
            newGrid.space = space
            newGrid.type = "list"
            newGrid.size_ = selectedSize.coreDataValue
            do {
                try viewContext.save()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            } catch {
                print("Error creating grid: \(error)")
            }
        }
    }

    private func inviteLink() -> String {
        "Join my Space: \(space.name ?? "")\n\ngridapp://join/\(space.id?.uuidString ?? "")"
    }
}