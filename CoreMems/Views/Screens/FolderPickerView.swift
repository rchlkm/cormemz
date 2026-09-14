import SwiftUI

struct FolderPickerView: View {
  let folders: [Folder]
  let assignedFolderIDs: Set<String>
  let onToggle: (String) -> Void
  let onCreate: (String, String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var creating = false
  @State private var name = ""
  @State private var emoji = "📁"

  private let emojiOptions = ["🐶", "🐱", "🌿", "✈️", "🏡", "🌅", "🎉", "❤️", "📸", "🌊"]

  var body: some View {
    NavigationStack {
      List {
        if !creating {
          ForEach(folders) { folder in
            Button {
              onToggle(folder.id)
            } label: {
              HStack {
                Text(folder.emoji)
                Text(folder.name).foregroundStyle(.primary)
                Spacer()
                if assignedFolderIDs.contains(folder.id) {
                  Image(systemName: "checkmark").foregroundStyle(.green)
                }
              }
            }
          }

          Button {
            creating = true
          } label: {
            Label("New folder", systemImage: "plus")
          }
        } else {
          Section("Pick an emoji") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
              ForEach(emojiOptions, id: \.self) { e in
                Button {
                  emoji = e
                } label: {
                  Text(e)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                      emoji == e ? Color.primary.opacity(0.12) : .clear,
                      in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
              }
            }
          }

          Section {
            TextField("Folder name (e.g. Doggo)", text: $name)
          }

          Section {
            Button("Create folder") {
              guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
              onCreate(name, emoji)
              name = ""
              emoji = "📁"
              creating = false
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
      }
      .navigationTitle("Add to folder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}
