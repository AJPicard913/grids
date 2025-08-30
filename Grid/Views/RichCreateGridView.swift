import SwiftUI
import CoreData
import PhotosUI

// --- Data Models for the Editor ---

struct ContentBlock: Identifiable, Hashable {
    let id = UUID()
    var type: BlockType
    var content: String = ""
    var isCompleted: Bool = false
    var imageData: Data?
}

enum BlockType: Hashable {
    case text, todo, image
}


// --- Main Editor View ---

struct RichCreateGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var space: Space
    
    @State private var gridTitle: String = ""
    @State private var contentBlocks: [ContentBlock] = [ContentBlock(type: .text)]
    @State private var showingPhotoPicker = false
    @State private var showingInviteSheet = false
    @FocusState private var focusedBlockId: UUID?

    init(space: Space, initialTitle: String? = nil, initialBlocks: [ContentBlock]? = nil) {
        self.space = space
        if let initialTitle {
            _gridTitle = State(initialValue: initialTitle)
        }
        if let initialBlocks {
            _contentBlocks = State(initialValue: initialBlocks)
        }
    }

    private var isSaveButtonEnabled: Bool {
        !gridTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Content VStack
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title Field with top padding to avoid the close button
                        TextField("Grid Title...", text: $gridTitle)
                            .font(.largeTitle.weight(.bold))
                            .padding(.horizontal)
                            .padding(.top, 50) // Padding for close button
                            .padding(.bottom, 8)

                        // The rest of the editor content
                        ForEach($contentBlocks) { $block in
                            contentBlockView(for: $block)
                        }
                    }
                }
                // Bottom Toolbar
                editorToolbar
            }
            
            // Close Button Overlay
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.secondary.opacity(0.8))
                    .font(.largeTitle)
            }
            .padding()
        }
        .sheet(isPresented: $showingPhotoPicker) { PhotoPicker(onImageSelected: handleImageSelection) }
        .sheet(isPresented: $showingInviteSheet) { InviteMemberView(space: space) }
    }

    // --- Subviews ---
    
    @ViewBuilder
    private func contentBlockView(for block: Binding<ContentBlock>) -> some View {
        let blockId = block.wrappedValue.id
        
        switch block.wrappedValue.type {
        case .text, .todo:
            HStack(spacing: 8) {
                if block.wrappedValue.type == .todo {
                    Button { block.wrappedValue.isCompleted.toggle() } label: {
                        Image(systemName: block.wrappedValue.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(block.wrappedValue.isCompleted ? .green : .secondary).font(.title3)
                    }
                }
                
                EditorTextView(text: block.content, placeholder: placeholder(for: block.wrappedValue))
                    .focused($focusedBlockId, equals: blockId)
                    .strikethrough(block.wrappedValue.type == .todo && block.wrappedValue.isCompleted)
                    .onReturn { handleReturn(for: block.wrappedValue) }
                    .onBackspace { handleBackspace(for: block.wrappedValue) }
            }
            .padding(.horizontal)

        case .image:
            if let imageData = block.wrappedValue.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable().aspectRatio(contentMode: .fill).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding([.horizontal, .vertical], 8)
            }
        }
    }
    
    private var editorToolbar: some View {
        HStack(spacing: 16) {
            Button { toggleTodo() } label: { Image(systemName: "list.bullet") }
            Button { } label: { Image(systemName: "textformat.size") } // Placeholder
            Button { showingPhotoPicker = true } label: { Image(systemName: "photo") }
            Button { showingInviteSheet = true } label: { Image(systemName: "person.badge.plus") }
            Spacer()
            Button(action: saveGrid) {
                Image(systemName: "arrow.right")
                    .foregroundColor(.white).frame(width: 44, height: 44)
                    .background(isSaveButtonEnabled ? Color("primaryPurple") : Color.gray)
                    .clipShape(Circle())
            }
            .disabled(!isSaveButtonEnabled)
        }
        .font(.title2).padding().background(.thinMaterial)
    }

    // --- LOGIC ---
    
    private func placeholder(for block: ContentBlock) -> String {
        if block.type == .todo { return "To-do item" }
        if contentBlocks.first?.id == block.id { return "Start typing..." }
        return ""
    }
    
    private func toggleTodo() {
        guard let focusedId = focusedBlockId, let index = contentBlocks.firstIndex(where: { $0.id == focusedId }) else { return }
        contentBlocks[index].type = contentBlocks[index].type == .todo ? .text : .todo
    }
    
    private func handleReturn(for block: ContentBlock) {
        guard let currentIndex = contentBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        
        if block.type == .todo && block.content.isEmpty {
            contentBlocks[currentIndex].type = .text
        } else {
            let newBlock = ContentBlock(type: block.type, content: "")
            contentBlocks.insert(newBlock, at: currentIndex + 1)
            focusedBlockId = newBlock.id
        }
    }

    private func handleBackspace(for block: ContentBlock) {
        guard let currentIndex = contentBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        
        if currentIndex == 0 {
            if block.type == .todo { contentBlocks[currentIndex].type = .text }
            return
        }
        
        let previousIndex = currentIndex - 1
        let previousBlockId = contentBlocks[previousIndex].id
        
        if contentBlocks[previousIndex].type == .text {
            contentBlocks[previousIndex].content.append(block.content)
        }

        contentBlocks.remove(at: currentIndex)
        focusedBlockId = previousBlockId
    }

    private func handleImageSelection(imageData: Data) {
        guard let focusedId = focusedBlockId, let focusedIndex = contentBlocks.firstIndex(where: { $0.id == focusedId }) else {
            contentBlocks.append(ContentBlock(type: .image, imageData: imageData))
            contentBlocks.append(ContentBlock(type: .text)); return
        }
        
        contentBlocks.insert(ContentBlock(type: .image, imageData: imageData), at: focusedIndex + 1)
        let newTextBlock = ContentBlock(type: .text)
        contentBlocks.insert(newTextBlock, at: focusedIndex + 2)
        focusedBlockId = newTextBlock.id
    }

    private func saveGrid() {
        withAnimation {
            let newGrid = Grid(context: viewContext)
            newGrid.id = UUID(); newGrid.title = gridTitle; newGrid.createdAt = Date();
            newGrid.updatedAt = Date(); newGrid.space = space; newGrid.type = "rich_content"

            for block in contentBlocks where !(block.type == .text && block.content.isEmpty) {
                let gridItem = GridItem(context: viewContext)
                gridItem.id = UUID(); gridItem.createdAt = Date(); gridItem.content = block.content
                gridItem.isCompleted = block.isCompleted
                
                switch block.type {
                    case .text: gridItem.type = "text"
                    case .todo: gridItem.type = "todo"
                    case .image: gridItem.type = "image"; gridItem.imageData = block.imageData
                }
                newGrid.addToItems(gridItem)
            }
            do { try viewContext.save(); dismiss() } catch { print("Error saving grid: \(error)") }
        }
    }
}


// --- SUPPORTING VIEWS (RE-ENGINEERED) ---

private struct OnReturnKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
private struct OnBackspaceKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var onReturn: () -> Void { get { self[OnReturnKey.self] } set { self[OnReturnKey.self] = newValue } }
    var onBackspace: () -> Void { get { self[OnBackspaceKey.self] } set { self[OnBackspaceKey.self] = newValue } }
}
extension View {
    func onReturn(perform action: @escaping () -> Void) -> some View { self.environment(\.onReturn, action) }
    func onBackspace(perform action: @escaping () -> Void) -> some View { self.environment(\.onBackspace, action) }
}

class DeletableUITextView: UITextView {
    var onDeleteBackward: (() -> Void)?
    override func deleteBackward() {
        if attributedText.string.isEmpty { onDeleteBackward?() }
        super.deleteBackward()
    }
}

struct EditorTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Environment(\.onReturn) var onReturn
    @Environment(\.onBackspace) var onBackspace

    func makeUIView(context: Context) -> DeletableUITextView {
        let textView = DeletableUITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isScrollEnabled = false; textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0; textView.textContainerInset = .zero
        textView.onDeleteBackward = { onBackspace() }
        return textView
    }

    func updateUIView(_ uiView: DeletableUITextView, context: Context) {
        if !uiView.isFirstResponder || uiView.text != text {
            if text.isEmpty {
                uiView.text = placeholder
                uiView.textColor = .placeholderText
            } else {
                uiView.text = text
                uiView.textColor = .label
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditorTextView
        init(_ parent: EditorTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = nil; textView.textColor = .label
            }
        }
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder; textView.textColor = .placeholderText
            }
        }
        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor != .placeholderText {
                 parent.text = textView.text
            }
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onReturn(); return false
            }
            return true
        }
    }
}

struct InviteMemberView: View {
    @Environment(\.managedObjectContext) private var viewContext; @Environment(\.dismiss) private var dismiss
    @ObservedObject var space: Space; @State private var inviteeName = ""; @State private var inviteeEmail = ""
    @State private var showingShareSheet = false
    private var members: [Member] {
        (space.members as? Set<Member> ?? []).sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
    }
    var body: some View {
        NavigationView {
            Form {
                Section("Invite Member") {
                    TextField("Name", text: $inviteeName).textInputAutocapitalization(.words)
                    TextField("Email", text: $inviteeEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                Section("Current Members") {
                    ForEach(members) { member in
                        HStack {
                            Circle().fill(Color.blue).frame(width: 30, height: 30)
                                .overlay(Text(String(member.name?.first ?? "?")).foregroundColor(.white).font(.caption.bold()))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name ?? "Unknown").font(.subheadline)
                                Text(member.email ?? "").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if member.isOwner {
                                Text("Owner").font(.caption).padding(.horizontal, 8).padding(.vertical, 2).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(4)
                            }
                        }.padding(.vertical, 2)
                    }
                }
                Section { Button("Share Grid Link") { showingShareSheet = true }.frame(maxWidth: .infinity, alignment: .center) }
            }
            .navigationTitle("Invite Members").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Invite") { inviteMember() }.disabled(inviteeName.isEmpty || inviteeEmail.isEmpty) }
            }
        }.sheet(isPresented: $showingShareSheet) { ShareSheet(items: [generateInviteLink()]) }
    }
    private func inviteMember() {
        withAnimation {
            let newMember = Member(context: viewContext)
            newMember.id = UUID(); newMember.name = inviteeName; newMember.email = inviteeEmail
            newMember.isOwner = false; newMember.joinedAt = Date(); newMember.space = space
            do { try viewContext.save(); inviteeName = ""; inviteeEmail = "" } catch { print("Error: \(error)") }
        }
    }
    private func generateInviteLink() -> String { "Join my Space: \(space.name ?? "")\n\ngridapp://join/\(space.id?.uuidString ?? "")" }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_: UIActivityViewController, context: Context) {}
}

struct PhotoPicker: UIViewControllerRepresentable {
    var onImageSelected: (Data) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let image = image as? UIImage, let data = image.jpegData(compressionQuality: 0.8) else { return }
                DispatchQueue.main.async { self.parent.onImageSelected(data) }
            }
        }
    }
}