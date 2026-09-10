import SwiftUI

struct HomeView: View {
  let photoCount: Int
  let limitedAccess: Bool
  let emptyLibrary: Bool
  let onStart: () -> Void
  let onManageAccess: () -> Void

  var body: some View {
    if emptyLibrary {
      emptyState
    } else {
      mainContent
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.system(size: 26, weight: .light))
        .foregroundStyle(.secondary)
        .frame(width: 60, height: 60)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

      Text("Nothing to review yet")
        .font(.title2.bold())

      Text(
        "Core Mems couldn't find any photos to go through. Check your Photos access, or come back once you've taken a few."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 24)

      Button("Check Photos access", action: onManageAccess)
        .buttonStyle(.bordered)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var mainContent: some View {
    VStack(spacing: 0) {
      if limitedAccess {
        Button(action: onManageAccess) {
          HStack(spacing: 10) {
            Image(systemName: "lock.open")
            Text("You've shared a limited set of photos. **Manage access**")
              .font(.footnote)
              .multilineTextAlignment(.leading)
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding([.horizontal, .top])
      }

      Spacer()

      VStack(alignment: .leading, spacing: 14) {
        Text("\(photoCount, format: .number.grouping(.automatic)) photos")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(.thinMaterial, in: Capsule())

        Text("Just one few photos!")
          .font(.largeTitle.bold())

        Text(
          "Review a small, random handful of photos."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)

        Button(action: onStart) {
          Text("Start a session")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
      }
      .padding(.horizontal, 30)

      Spacer()

      Text("Deleted photos move to Recently Deleted — never gone right away.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.bottom, 24)
    }
  }
}

#Preview {
  HomeView(
    photoCount: 26909, limitedAccess: false, emptyLibrary: false, onStart: {}, onManageAccess: {})
}
