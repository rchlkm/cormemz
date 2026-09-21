// CoreMems/Views/Components/PhotoGrid.swift
import SwiftUI

struct PhotoGrid: View {
  let photos: [SessionPhoto]
  var showsDecisionTags = false
  let onRestore: (String) -> Void

  var body: some View {
    if !photos.isEmpty {
      ScrollView {
        PhotoGridCells(
          photos: photos, showsDecisionTags: showsDecisionTags, onRestore: onRestore)
      }
    }
  }
}

/// The grid without a scroll view, for screens that supply their own.
/// Tapping a photo opens it full screen, where its mark can be undone.
/// Decision tags tell deletions and conversions apart.
struct PhotoGridCells: View {
  let photos: [SessionPhoto]
  var showsDecisionTags = false
  let onRestore: (String) -> Void

  @State private var viewing: SessionPhoto?

  var body: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
      spacing: 10
    ) {
      ForEach(photos) { photo in
        ZStack(alignment: .topTrailing) {
          Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
              AdaptiveAssetImage(photo: photo, targetSize: CGSize(width: 200, height: 200))
                .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { viewing = photo }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("View photo")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(AccessibilityID.gridPhoto)

          Button {
            onRestore(photo.id)
          } label: {
            Image(systemName: "arrow.uturn.backward")
          }
          .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
          .accessibilityIdentifier(AccessibilityID.trayRestore)
          .padding(6)
        }
        .overlay(alignment: .bottomLeading) {
          if showsDecisionTags {
            DecisionTag(decision: photo.decision)
              .padding(6)
          }
        }
      }
    }
    .padding(.horizontal, 26)
    .padding(.top, 16)
    .fullScreenCover(item: $viewing) { photo in
      FullScreenPhotoView(photo: photo, onUndo: { onRestore(photo.id) })
    }
  }
}

/// Small badge naming what will happen to a marked photo. Empty for any other decision.
private struct DecisionTag: View {
  let decision: ReviewDecision

  private var style: (symbol: String, color: Color)? {
    switch decision {
    case .pendingDelete: return ("trash", decision.tint)
    case .convertToStill: return ("livephoto.slash", decision.tint)
    case .keep, .undecided: return nil
    }
  }

  var body: some View {
    if let style {
      Image(systemName: style.symbol)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 26, height: 26)
        .background(style.color.opacity(0.85), in: Circle())
    }
  }
}
