// CoreMems/Services/HapticsService.swift
import AudioToolbox
import UIKit

protocol HapticsServicing {
  func keep()
  func markForDeletion()
  func convertToStill()
  func goBack()
  func trayRestore()
  //  func confirmDelete()
  func sessionComplete()
  func favorite()
  func albumToggle()
}

extension HapticsServicing {
  func decided(_ decision: ReviewDecision) {
    switch decision {
    case .keep: keep()
    case .pendingDelete: markForDeletion()
    case .convertToStill: convertToStill()
    case .undecided: break
    }
  }
}

/// Haptic + system-sound feedback for review decisions.
///
/// `AudioServicesPlaySystemSound` respects the ring/silent switch by
/// default on real hardware — no extra gating needed. (The iOS
/// Simulator has no physical switch and will always play sound
/// regardless of this code; that's a Simulator limitation, not a bug.)
final class HapticsService: HapticsServicing {
  private let successGenerator = UINotificationFeedbackGenerator()
  private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
  private let lightImpact = UIImpactFeedbackGenerator(style: .light)
  private let softImpact = UIImpactFeedbackGenerator(style: .soft)
  private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
  private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
  private let selectionFeedback = UISelectionFeedbackGenerator()

  var isSoundEnabled = true

  private enum SystemSound: SystemSoundID {
    case keep = 1057  // 1004
    case markForDeletion = 1051
    case convertToStill = 1108  // photo shutter
    case goBack = 1053  // error
    case trayRestore = 1054
    // case confirmDelete = 1050
    case sessionComplete = 1109 //1050
    case favorite = 1111
    // case keep = 1111
    // case markForDeletion = 1110
    // case goBack = 1053
    // case trayRestore = 1109
    // case confirmDelete = 1050
    // case sessionComplete = 1335
    // 1109 Shake to shuffle
    // 1001 send
    // 1112
    // 1116
    // 1050
    // 1051
    // 1052
  }

  func keep() {
    successGenerator.notificationOccurred(.success)
    play(.keep)
  }

  func markForDeletion() {
    mediumImpact.impactOccurred()
    play(.markForDeletion)
  }

  func convertToStill() {
    rigidImpact.impactOccurred()
    play(.convertToStill)
  }

  func goBack() {
    lightImpact.impactOccurred()
    play(.goBack)
  }

  func trayRestore() {
    softImpact.impactOccurred()
    play(.trayRestore)
  }

  // func confirmDelete() {
  //   heavyImpact.impactOccurred()
  //   play(.confirmDelete)
  // }

  func sessionComplete() {
    rigidImpact.impactOccurred()
    play(.sessionComplete)
  }

  func favorite() {
    play(.favorite)
  }

  func albumToggle() {
    selectionFeedback.selectionChanged()
  }

  private func play(_ sound: SystemSound) {
    guard isSoundEnabled else { return }
    AudioServicesPlaySystemSound(sound.rawValue)
  }
}

final class MockHapticsService: HapticsServicing {
  private(set) var keepCallCount = 0
  private(set) var markForDeletionCallCount = 0
  private(set) var convertToStillCallCount = 0
  private(set) var goBackCallCount = 0
  private(set) var trayRestoreCallCount = 0
  // private(set) var confirmDeleteCallCount = 0
  private(set) var sessionCompleteCallCount = 0
  private(set) var favoriteCount = 0
  private(set) var albumToggleCount = 0

  func keep() { keepCallCount += 1 }
  func markForDeletion() { markForDeletionCallCount += 1 }
  func convertToStill() { convertToStillCallCount += 1 }
  func goBack() { goBackCallCount += 1 }
  func trayRestore() { trayRestoreCallCount += 1 }
  // func confirmDelete() { confirmDeleteCallCount += 1 }
  func sessionComplete() { sessionCompleteCallCount += 1 }
  func favorite() { favoriteCount += 1 }
  func albumToggle() { albumToggleCount += 1 }

}

#if DEBUG
  import SwiftUI

  let service = HapticsService()

  #Preview("Haptics Service Test") {
    Button("keep") {
      service.keep()
    }
    .buttonStyle(.borderedProminent)

    Button("go back") {
      service.goBack()
    }
    .buttonStyle(.borderedProminent)

    Button("markForDeletion") {
      service.markForDeletion()
    }
    .buttonStyle(.borderedProminent)

    Button("convertToStill") {
      service.convertToStill()
    }
    .buttonStyle(.borderedProminent)

    Button("trayRestore") {
      service.trayRestore()
    }
    .buttonStyle(.borderedProminent)

    Button("sessionComplete") {
      service.sessionComplete()
    }
    .buttonStyle(.borderedProminent)

    Button("favorite") {
      service.favorite()
    }
    .buttonStyle(.borderedProminent)

    Button("albumToggle") {
      service.albumToggle()
    }
    .buttonStyle(.borderedProminent)
  }
#endif
