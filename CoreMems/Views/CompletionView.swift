import Foundation
import SwiftUI

struct CompletionView: View {
  let keptCount: Int
  let deletedCount: Int
  let lifetimeStats: LifetimeSessionStats
  let onAgain: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(.green)

      Text("Session complete")
        .font(.title2.bold())

      Text(
        "You kept \(keptCount) photo\(keptCount == 1 ? "" : "s")"
          + (deletedCount > 0 ? " and moved \(deletedCount) to Recently Deleted." : ".")
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)

      if deletedCount > 0 {
        Text("They're recoverable from the Photos app if you change your mind.")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      Divider()
        .padding(.horizontal, 32)

      VStack(spacing: 4) {
        Text("Lifetime stats")
          .font(.headline)

        VStack(spacing: 2) {
          Text("Total photos reviewed: \(lifetimeStats.totalReviewed)")
          Text("Total kept: \(lifetimeStats.totalKept)")
          Text("Total deleted: \(lifetimeStats.totalDeleted)")
          Text("Sessions completed: \(lifetimeStats.sessionsCompleted)")
          if let date = lifetimeStats.trackingSince {
            Text("Tracking since: \(dateFormatted(date))")
          }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 32)

      Spacer()

      Button("Another session", action: onAgain)
        .buttonStyle(PrimaryActionButtonStyle())
    }
  }

  private func dateFormatted(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }
}

struct CompletionScreen_Preview: PreviewProvider {
  static var previews: some View {
    CompletionView(
      keptCount: 7,
      deletedCount: 3,
      lifetimeStats: LifetimeSessionStats(
        totalReviewed: 150,
        totalKept: 100,
        totalDeleted: 50,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)  // Jan 1, 2022
      ),
      onAgain: {})
  }
}
