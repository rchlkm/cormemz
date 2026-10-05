// CoreMems/Views/Sheets/AlbumEmojiPickerView.swift
import SwiftUI

/// Chooses the emoji that replaces an album's icon, using the system emoji keyboard.
struct AlbumEmojiPickerView: View {
  let album: AlbumOption
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  @Environment(\.dismiss) private var dismiss

  private var emoji: AlbumEmoji? { pinnedAlbums.albumEmoji[album.ref.identifier] }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        EmojiField(
          emoji: Binding(
            get: { emoji },
            set: { pinnedAlbums.setEmoji($0, forAlbum: album.ref.identifier) })
        )
        .frame(height: 80)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))

        Button("Use Default Icon", systemImage: "photo.stack") {
          pinnedAlbums.setEmoji(nil, forAlbum: album.ref.identifier)
        }
        .disabled(emoji == nil)
        Spacer()
      }
      .padding()
      .navigationTitle(album.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
    .presentationDetents([.medium])
  }
}

/// A text field that opens the emoji keyboard and holds the last emoji typed.
private struct EmojiField: UIViewRepresentable {
  @Binding var emoji: AlbumEmoji?

  func makeUIView(context: Context) -> EmojiTextField {
    let field = EmojiTextField()
    field.font = .systemFont(ofSize: 48)
    field.textAlignment = .center
    field.tintColor = .clear
    field.attributedPlaceholder = NSAttributedString(
      string: "Type an emoji", attributes: [.font: UIFont.preferredFont(forTextStyle: .body)])
    field.accessibilityIdentifier = AccessibilityID.emojiPickerField
    field.addTarget(
      context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
    return field
  }

  func updateUIView(_ field: EmojiTextField, context: Context) {
    context.coordinator.parent = self
    field.text = emoji?.value
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject {
    var parent: EmojiField

    init(parent: EmojiField) { self.parent = parent }

    /// Keeps the last character typed if it's an emoji; anything else is discarded.
    @objc func textChanged(_ field: UITextField) {
      if let last = field.text?.last, let typed = AlbumEmoji(String(last)) {
        parent.emoji = typed
      }
      field.text = parent.emoji?.value
    }
  }
}

private final class EmojiTextField: UITextField {
  override var textInputMode: UITextInputMode? {
    UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() } }
  }
}

#Preview {
  AlbumEmojiPickerView(
    album: AlbumOption(ref: .existing(localIdentifier: "1"), name: "Trips"),
    pinnedAlbums: .mock())
}
