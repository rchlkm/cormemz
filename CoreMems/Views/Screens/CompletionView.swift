// CoreMems/Views/Screens/CompletionView.swift
import Foundation
import SwiftUI

struct CompletionView: View {
  let keptCount: Int
  let deletedCount: Int
  let albumAssignedCount: Int
  let convertedCount: Int
  let lifetimeStats: LifetimeSessionStats
  let onAgain: () -> Void

  private var summaryText: String {
    var clauses = ["kept \(keptCount) photo\(keptCount == 1 ? "" : "s")"]
    if deletedCount > 0 {
      clauses.append("moved \(deletedCount) to Recently Deleted")
    }
    if albumAssignedCount > 0 {
      clauses.append("added \(albumAssignedCount) to an album")
    }
    if convertedCount > 0 {
      clauses.append("converted \(convertedCount) Live Photo\(convertedCount == 1 ? "" : "s") to stills")
    }
    return "You " + Self.naturalJoin(clauses) + "."
  }

  private static func naturalJoin(_ items: [String]) -> String {
    switch items.count {
    case 1: return items[0]
    case 2: return "\(items[0]) and \(items[1])"
    default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(.green)

      Text("Session complete")
        .font(.title2.bold())

      Text(summaryText)
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
        .buttonStyle(ActionButtonStyle(role: .primary))
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
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
      albumAssignedCount: 2,
      convertedCount: 1,
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
