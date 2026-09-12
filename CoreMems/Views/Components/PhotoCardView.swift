// CoreMems/Views/Components/PhotoCardView.swift
import SwiftUI

/// Draggable photo card. Purely presentational — gesture handling and
/// commit logic live in `ReviewView` so decisions always flow through
/// the view model's single source of truth.
struct PhotoCardView: View {
  let photo: SessionPhoto
  @Binding var dragOffset: CGSize
  /// Available space for the photo itself — pass the review area's
  /// GeometryReader size (minus a little padding) so landscape photos
  /// can go full-width and portrait photos full-height, never cropped
  /// or overflowing the screen.
  var maxSize: CGSize
  var onShowDetails: () -> Void = {}
  var onTapFullScreen: () -> Void = {}

  var body: some View {
    AdaptiveAssetImage(photo: photo, fitWithin: maxSize)
      .clipShape(RoundedRectangle(cornerRadius: 26))
      .overlay(dateAndInfoOverlay, alignment: .bottom)
      .overlay(alignment: .topLeading) {
        if photo.isFavorite { favoriteBadge }
      }
      .overlay(keepDeleteStamps)
      .contentShape(RoundedRectangle(cornerRadius: 26))
      .onTapGesture { onTapFullScreen() }
      .offset(dragOffset)
      .rotationEffect(.degrees(Double(dragOffset.width / 18)))
      .shadow(radius: 16, y: 8)
      .animation(.easeOut(duration: 0.2), value: dragOffset)
  }

  private var favoriteBadge: some View {
    Image(systemName: "heart.fill")
      .foregroundStyle(.pink)
      .padding(8)
      .background(.white.opacity(0.9), in: Circle())
      .padding(12)
  }

  private var dateAndInfoOverlay: some View {
    ZStack {
      LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top)
        .frame(height: 60)

      HStack {
        if !photo.dateLabel.isEmpty {
          Text(photo.dateLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
        }
        Spacer()
        Button(action: onShowDetails) {
          Image(systemName: "info.circle.fill")
            .foregroundStyle(.white.opacity(0.9))
        }
      }
      .padding(.horizontal, 14)
    }
    .frame(height: 60)
  }

  private var keepDeleteStamps: some View {
    let keepOpacity = min(1, max(0, dragOffset.width / 90))
    let delOpacity = min(1, max(0, dragOffset.height / 90))
    let detailsOpacity = min(1, max(0, -dragOffset.height / 90))
    return VStack {
      HStack {
        Text("KEEP")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.green.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .rotationEffect(.degrees(-6))
          .opacity(keepOpacity)
        Spacer()
        Text("DETAILS")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .opacity(detailsOpacity)
      }
      Spacer()
      HStack {
        Spacer()
        Text("DELETE")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .opacity(delOpacity)
      }
    }
    .padding(14)
  }
}
