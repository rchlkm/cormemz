// CoreMems/Views/Components/PeekFilmstripView.swift
import SwiftUI

/// Scrolling filmstrip of a photo's library neighbors, oldest to newest. Whichever thumbnail
/// is centered is the focused one; the anchor photo carries an accent marker.
struct PeekFilmstripView: View {
  let neighbors: [SessionPhoto]
  let anchorID: String
  let focusedID: String
  /// The side being extended once the strip is showing photos.
  let loadingSide: PeekSide?
  let isLoadingInitialNeighbors: Bool
  let onFocus: (String) -> Void

  static let thumbnailHeight: CGFloat = 64
  static let verticalPadding: CGFloat = 10
  static var height: CGFloat { thumbnailHeight + 2 * verticalPadding }

  private static let thumbnailWidth: CGFloat = 40
  private static let focusedWidth: CGFloat = 64
  private static let spacing: CGFloat = 4
  private static let loadingWidth: CGFloat = 30
  private static let cornerRadius: CGFloat = 8
  private static let borderWidth: CGFloat = 3
  private static let badgePadding: CGFloat = 3

  var body: some View {
    GeometryReader { proxy in
      let margin = (proxy.size.width - Self.focusedWidth) / 2
      ScrollViewReader { reader in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: Self.spacing) {
            loadingIndicator(.older)
            HStack(spacing: Self.spacing) {
              ForEach(neighbors) { neighbor in
                thumbnail(neighbor)
                  .onTapGesture { withAnimation(.snappy) { onFocus(neighbor.id) } }
              }
            }
            .scrollTargetLayout()
            loadingIndicator(.newer)
          }
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: focusBinding, anchor: .center)
        .onChange(of: neighbors.isEmpty) { _, isEmpty in
          guard !isEmpty else { return }
          Task {
            await Task.yield()
            reader.scrollTo(anchorID, anchor: .center)
          }
        }
        .overlay {
          if isLoadingInitialNeighbors && neighbors.isEmpty {
            ProgressView().tint(.white)
          }
        }
      }
    }
    .frame(height: Self.height)
    .background(.black.opacity(0.55))
  }

  private var focusBinding: Binding<String?> {
    Binding(
      get: { focusedID },
      set: { if let id = $0 { onFocus(id) } })
  }

  @ViewBuilder
  private func loadingIndicator(_ side: PeekSide) -> some View {
    if loadingSide == side {
      ProgressView()
        .tint(.white)
        .frame(width: Self.loadingWidth, height: Self.thumbnailHeight)
    }
  }

  private func thumbnail(_ neighbor: SessionPhoto) -> some View {
    let isAnchor = neighbor.id == anchorID
    let isFocused = neighbor.id == focusedID
    let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
    return AdaptiveAssetImage(photo: neighbor, targetSize: CGSize(width: 200, height: 200))
      .frame(
        width: isFocused ? Self.focusedWidth : Self.thumbnailWidth, height: Self.thumbnailHeight
      )
      .clipped()
      .clipShape(shape)
      .overlay(shape.stroke(borderColor(isAnchor: isAnchor), lineWidth: isAnchor || isFocused ? Self.borderWidth : 0))
      .overlay(alignment: .bottom) {
        if isAnchor { AnchorMarker(showsLabel: isFocused) }
      }
      .overlay(alignment: .topTrailing) {
        if neighbor.decision != .undecided {
          DecisionBadge(decision: neighbor.decision).padding(Self.badgePadding)
        }
      }
      .animation(.snappy(duration: 0.15), value: isFocused)
  }

  private func borderColor(isAnchor: Bool) -> Color {
    isAnchor ? .accentColor : .white
  }
}

/// Accent tag on the anchor photo's thumbnail; a bare pill when the thumbnail is too narrow
/// for text.
private struct AnchorMarker: View {
  let showsLabel: Bool

  var body: some View {
    Group {
      if showsLabel {
        Text("In session")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(Color.accentColor, in: Capsule())
      } else {
        Capsule().fill(Color.accentColor).frame(width: 12, height: 5)
      }
    }
    .padding(.bottom, 4)
  }
}

/// Small round icon marking a photo's decision on a thumbnail.
private struct DecisionBadge: View {
  let decision: ReviewDecision

  var body: some View {
    Image(systemName: DecisionOverlay.content(for: decision).icon)
      .font(.system(size: 10, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 20, height: 20)
      .background(decision.tint, in: Circle())
  }
}
