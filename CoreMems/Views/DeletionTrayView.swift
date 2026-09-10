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
          List {
            ForEach(items) { photo in
              HStack(spacing: 12) {
                AdaptiveAssetImage(photo: photo, targetSize: CGSize(width: 46, height: 46))
                  .frame(width: 46, height: 46)
                  .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Marked for deletion")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)

                Spacer()

                Button("Restore") { onRestore(photo.id) }
                  .buttonStyle(.bordered)
                  .tint(.green)
              }
            }
          }
          .listStyle(.plain)
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
