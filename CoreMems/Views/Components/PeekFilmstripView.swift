// CoreMems/Views/Components/PeekFilmstripView.swift
import SwiftUI

/// Scrolling filmstrip of a photo's library neighbors, oldest to newest, shown in place of the
/// review buttons, with a delete button floating over its right end. Whichever thumbnail is centered is the
/// focused one; the anchor photo carries an accent marker.
struct PeekFilmstripView: View {
  let neighbors: [SessionPhoto]
  let anchorID: String
  let focusedID: String
  /// The side being extended once the strip is showing photos.
  let loadingSide: PeekSide?
  let isLoadingInitialNeighbors: Bool
  let onFocus: (String) -> Void
  /// Whether the focused photo is marked for deletion, which turns the delete button into a restore.
  let isFocusedMarkedForDeletion: Bool
  /// Marks the focused photo for deletion, or restores it if it already is.
  let onToggleDelete: () -> Void

  private static let thumbnailHeight: CGFloat = 64
  private static let verticalPadding: CGFloat = 18
  private static var height: CGFloat { thumbnailHeight + 2 * verticalPadding }
  private static let thumbnailWidth: CGFloat = 52
  private static let focusedWidth: CGFloat = 72
  private static let spacing: CGFloat = 4
  private static let loadingWidth: CGFloat = 30
  private static let cornerRadius: CGFloat = 8
  private static let borderWidth: CGFloat = 3
  private static let badgePadding: CGFloat = 3
  private static let labelPadding: CGFloat = 4
  private static let dimmedOpacity: Double = 0.7
  private static let deleteTrailingPadding: CGFloat = 16

  var body: some View {
    filmstrip
      .frame(height: Self.height)
      .overlay(alignment: .trailing) { deleteButton }
  }

  private var deleteButton: some View {
    Button(action: onToggleDelete) {
      Image(systemName: isFocusedMarkedForDeletion ? "arrow.uturn.backward" : "trash")
    }
    .buttonStyle(
      IconButtonStyle(
        size: .large,
        surface: .tinted(isFocusedMarkedForDeletion ? .secondary : ReviewDecision.pendingDelete.tint))
    )
    .background(Circle().fill(.background))
    .padding(.trailing, Self.deleteTrailingPadding)
    .accessibilityIdentifier(
      isFocusedMarkedForDeletion ? AccessibilityID.reviewPeekRestore : AccessibilityID.reviewPeekDelete)
  }

  private var filmstrip: some View {
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
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
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
            ProgressView()
          }
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
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
        if isAnchor && isFocused { AnchorLabel().padding(.bottom, Self.labelPadding) }
      }
      .overlay(alignment: .topLeading) {
        if isAnchor { AnchorBadge().padding(Self.badgePadding) }
      }
      .overlay(alignment: .topTrailing) {
        if neighbor.decision != .undecided {
          DecisionBadge(decision: neighbor.decision).padding(Self.badgePadding)
        }
      }
      .opacity(isFocused || isAnchor ? 1 : Self.dimmedOpacity)
      .animation(.snappy(duration: 0.15), value: isFocused)
  }

  private func borderColor(isAnchor: Bool) -> Color {
    isAnchor ? .accentColor : .primary
  }
}

/// Accent label on the anchor photo's thumbnail while it is focused.
private struct AnchorLabel: View {
  var body: some View {
    Text("In session")
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.accentColor, in: Capsule())
  }
}

/// Accent bookmark on the anchor photo's thumbnail, shown whether or not it is focused.
private struct AnchorBadge: View {
  var body: some View {
    Image(systemName: "bookmark.fill")
      .font(.system(size: 10, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 20, height: 20)
      .background(Color.accentColor, in: Circle())
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
