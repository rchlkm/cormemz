// CoreMems/Views/ReviewView.swift
import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var showTray = false
  @State private var expandedPhoto: SessionPhoto?
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
            DeletionTrayButton(pendingCount: vm.pendingItems.count) { showTray = true }
          )
        )

        Text("Photo \(min(vm.currentIndex + 1, vm.photos.count)) of \(vm.photos.count)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
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
          photo: expandedPhoto, namespace: heroNamespace, expandedPhoto: $expandedPhoto
        )
        .ignoresSafeArea()
        .zIndex(1)
      }
    }
  }
}
