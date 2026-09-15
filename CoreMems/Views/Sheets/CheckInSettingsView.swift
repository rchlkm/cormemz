// CoreMems/Views/Sheets/CheckInSettingsView.swift
import SwiftUI

struct CheckInSettingsView: View {
  @Binding var value: Int

  private var range: ClosedRange<Double> {
    let bounds = SessionViewModel.checkInIntervalRange
    return Double(bounds.lowerBound)...Double(bounds.upperBound)
  }

  var body: some View {
    VStack(spacing: 20) {
      Text("Check-in frequency")
        .font(.headline)
        .padding(.top, 20)

      Text(
        "Every session keeps going until you stop. Pick how often you'd like a quick \"keep going?\" check-in along the way."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 24)

      VStack(spacing: 2) {
        Text("\(value)")
          .font(.system(size: 36, weight: .bold))
        Text("photo\(value == 1 ? "" : "s") between check-ins")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Slider(
          value: Binding(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
          ),
          in: range,
          step: 1
        )
        HStack {
          Text("\(SessionViewModel.checkInIntervalRange.lowerBound)")
          Spacer()
          Text("\(SessionViewModel.checkInIntervalRange.upperBound)")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 24)

      Spacer(minLength: 12)
    }
    .presentationDetents([.height(320)])
  }
}

#Preview {
  CheckInSettingsView(value: .constant(12))
}
