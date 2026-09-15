// CoreMems/Views/ReviewView.swift
import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var showTray = false
  @State private var expandedPhoto: SessionPhoto?
  @State private var showCheckIn = false
  @State private var lastCheckInIndex = -1
  @Namespace private var heroNamespace

  private var current: SessionPhoto? {
    vm.photos.indices.contains(vm.currentIndex) ? vm.photos[vm.currentIndex] : nil
  }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        TopBar(
          title: "",
          onBack: { vm.exitToHome() },
          trailing: AnyView(
            HStack(spacing: 12) {
              DeletionTrayButton(pendingCount: vm.pendingItems.count) { showTray = true }
              Button("Done") { vm.finishEarly() }
                .font(.system(size: 15, weight: .semibold))
            }
          )
        )

        VStack(spacing: 2) {
          Text("\(vm.currentIndex) reviewed")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          if let sessionLabel = vm.sessionLabel {
            Text(sessionLabel)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.bottom, 4)

        ZStack {
          if let current {
            GeometryReader { geo in
              let maxSize = CGSize(width: geo.size.width - 16, height: geo.size.height - 8)
              ReviewCardView(
                photo: current, maxSize: maxSize, vm: vm,
                namespace: heroNamespace, expandedPhoto: $expandedPhoto
              )
              .frame(width: geo.size.width, height: geo.size.height)
            }
          } else {
            ProgressView()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        ReviewControlBar(
          canUndo: vm.canUndo,
          onUndo: { vm.quickUndo() },
          onDelete: { vm.decide(index: vm.currentIndex, decision: .pendingDelete) },
          onKeep: { vm.decide(index: vm.currentIndex, decision: .keep) }
        )
      }
      .sheet(isPresented: $showTray) {
        DeletionTrayView(
          items: vm.pendingItems,
          onRestore: { id in vm.restoreMany(ids: [id]) }
        )
        .presentationDetents([.medium, .large])
      }

      if let expandedPhoto {
        ExpandedPhotoView(
          photo: expandedPhoto, vm: vm, namespace: heroNamespace, expandedPhoto: $expandedPhoto
        )
        .ignoresSafeArea()
        .zIndex(1)
      }

      if showCheckIn {
        CheckInOverlayView(
          reviewedCount: vm.currentIndex,
          onContinue: { showCheckIn = false },
          onDone: {
            showCheckIn = false
            vm.finishEarly()
          }
        )
        .zIndex(2)
      }
    }
    .onChange(of: vm.currentIndex) { _, newIndex in
      guard
        newIndex > 0,
        newIndex % vm.checkInInterval == 0,
        newIndex < vm.photos.count,
        lastCheckInIndex != newIndex
      else { return }
      lastCheckInIndex = newIndex
      showCheckIn = true
    }
  }
}

private struct CheckInOverlayView: View {
  @Environment(\.colorScheme) private var colorScheme
  let reviewedCount: Int
  let onContinue: () -> Void
  let onDone: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.42)
        .ignoresSafeArea()

      VStack(spacing: 14) {
        Text("👀")
          .font(.system(size: 30))
        Text("\(reviewedCount) photos reviewed")
          .font(.system(size: 18, weight: .bold))
        Text("Keep going, or call it here for now — your decisions are already saved.")
          .font(.system(size: 13.5))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button(action: onContinue) {
          Text("Keep going")
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundColor(colorScheme == .dark ? .black : .white)
        .background(
          colorScheme == .dark ? Color.white : Color.black, in: RoundedRectangle(cornerRadius: 14)
        )

        Button(action: onDone) {
          Text("I'm done for now")
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundColor(.primary)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
      }
      .padding(24)
      .frame(maxWidth: 300)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
      .shadow(radius: 24)
    }
  }
}
