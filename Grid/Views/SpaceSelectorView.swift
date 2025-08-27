import SwiftUI
import CoreData

struct SpaceSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let spaces: [Space]
    @Binding var selectedIndex: Int
    @Binding var showingCreateSpace: Bool
    @State private var isEditMode = false
    @State private var spaceToDelete: Space?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(space.name ?? "Unnamed Grid")
                                .font(.headline)
                            HStack {
                                Text("\((space.grids as? Set<Grid>)?.count ?? 0) items")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("•").foregroundColor(.secondary)
                                Text("\((space.members as? Set<Member>)?.count ?? 0) members")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if isEditMode {
                            Button {
                                spaceToDelete = space
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red).font(.title2)
                            }
                        } else if index == selectedIndex {
                            Image(systemName: "checkmark").foregroundColor(Color("primaryPurple"))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditMode {
                            spaceToDelete = space; showingDeleteAlert = true
                        } else {
                            selectedIndex = index; dismiss()
                        }
                    }
                }
                if !isEditMode {
                    Section {
                        Button {
                            showingCreateSpace = true; dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill").foregroundColor(Color("primaryPurple"))
                                Text("Add New Grid").foregroundColor(Color("primaryPurple"))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Grid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditMode { Button("Close") { dismiss() } }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Done" : "Edit") { withAnimation { isEditMode.toggle() } }
                }
            }
        }
        .alert("Delete Grid", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let spaceToDelete { deleteSpace(spaceToDelete) }
            }
        } message: {
            Text("Are you sure you want to delete this grid? This action cannot be undone.")
        }
    }
    
    private func deleteSpace(_ space: Space) {
        withAnimation {
            viewContext.delete(space)
            do { try viewContext.save() } catch { print("Error deleting: \(error)") }
        }
    }
}