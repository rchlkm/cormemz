import SwiftUI

struct DeletionTrayView: View {
  let items: [SessionPhoto]
  let onRestore: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if items.isEmpty {
          VStack(spacing: 10) {
            Image(systemName: "tray")
              .font(.largeTitle)
              .foregroundStyle(.tertiary)
            Text("Nothing marked for deletion yet. Swipe down on a photo to add it here.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 30)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          PhotoGrid(photos: items, onRestore: onRestore)
        }
      }
      .navigationTitle("Marked for deletion")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}
