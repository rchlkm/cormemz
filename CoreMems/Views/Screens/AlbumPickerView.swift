import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var creating = false
  @State private var name = ""

  var body: some View {
    NavigationStack {
      List {
        if !creating {
          ForEach(albums) { album in
            Button {
              onToggle(album.ref)
            } label: {
              HStack {
                Text(album.name).foregroundStyle(.primary)
                Spacer()
                if assignedRefs.contains(album.ref) {
                  Image(systemName: "checkmark").foregroundStyle(.green)
                }
              }
            }
          }

          Button {
            creating = true
          } label: {
            Label("New album", systemImage: "plus")
          }
        } else {
          Section {
            TextField("Album name (e.g. Doggo)", text: $name)
          }

          Section {
            Button("Create album") {
              guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
              onCreate(name)
              name = ""
              creating = false
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
      }
      .navigationTitle("Add to album")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}
