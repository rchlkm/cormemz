// CoreMems/Views/HomeSplashView.swift
import SwiftUI

/// Shown instead of the full Home screen once the user has already
/// onboarded and granted Photos access. Just confirms the library
/// size, then auto-advances to Setup — no decisions to make here.
struct HomeSplashView: View {
  let photoCount: Int
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      Spacer()
      Text("\(photoCount, format: .number.grouping(.automatic))")
        .font(.system(size: 44, weight: .bold))
      Text("photos on this phone")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      ProgressView()
        .padding(.top, 10)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .onTapGesture { onContinue() }  // tap to skip the wait
    .task {
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      onContinue()
    }
  }
}
