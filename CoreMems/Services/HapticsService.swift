// CoreMems/Services/HapticsService.swift
import AudioToolbox
import UIKit

protocol HapticsServicing {
  func keep()
  func markForDeletion()
  func undo()
  func trayRestore()
  func confirmDelete()
  func sessionComplete()
}

/// Per-action haptic + system-sound feedback for review decisions.
/// `UIFeedbackGenerator` already no-ops safely on hardware without a
/// Taptic Engine (Simulator, older iPads), so no extra capability
/// check is needed for the "unsupported hardware" requirement.
final class HapticsService: HapticsServicing {
  private let successGenerator = UINotificationFeedbackGenerator()
  private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
  private let lightImpact = UIImpactFeedbackGenerator(style: .light)
  private let softImpact = UIImpactFeedbackGenerator(style: .soft)
  private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
  private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)

  var isSoundEnabled = true

  private enum SystemSound: SystemSoundID {
    case keep = 1111  // JBL_Confirm
    case markForDeletion = 1256  // Tock (low)
    case undo = 1302
    case trayRestore = 1107
    case confirmDelete = 1050  // Camera Shutter
    case sessionComplete = 1335
    // 1109 Shake to shuffle
    // 1112
    // 1050
    // 1051

  }

  func keep() {
    successGenerator.notificationOccurred(.success)
    play(.keep)
  }

  func markForDeletion() {
    mediumImpact.impactOccurred()
    play(.markForDeletion)
  }

  func undo() {
    lightImpact.impactOccurred()
    play(.undo)
  }

  /// Lighter, keep-like feedback for restoring a photo from the
  /// Deletion Tray or the end-of-session grid.
  func trayRestore() {
    softImpact.impactOccurred()
    play(.trayRestore)
  }

  /// Fires once assets are actually submitted for deletion — the
  /// heaviest haptic in the set.
  func confirmDelete() {
    // heavyImpact.impactOccurred()
    // play(.confirmDelete)
  }

  func sessionComplete() {
    rigidImpact.impactOccurred()
    play(.sessionComplete)
  }

  private func play(_ sound: SystemSound) {
    guard isSoundEnabled else { return }
    AudioServicesPlaySystemSound(sound.rawValue)
  }
}

/// Records calls instead of touching hardware — used by previews,
/// SwiftUI Previews on unsupported hosts, and unit tests.
final class MockHapticsService: HapticsServicing {
  private(set) var keepCallCount = 0
  private(set) var markForDeletionCallCount = 0
  private(set) var undoCallCount = 0
  private(set) var trayRestoreCallCount = 0
  private(set) var confirmDeleteCallCount = 0
  private(set) var sessionCompleteCallCount = 0

  func keep() { keepCallCount += 1 }
  func markForDeletion() { markForDeletionCallCount += 1 }
  func undo() { undoCallCount += 1 }
  func trayRestore() { trayRestoreCallCount += 1 }
  func confirmDelete() { confirmDeleteCallCount += 1 }
  func sessionComplete() { sessionCompleteCallCount += 1 }
}

#if DEBUG
  import SwiftUI

  let service = HapticsService()

  #Preview("Haptics Service Test") {
    Button("keep") {
      service.keep()
    }
    .buttonStyle(.borderedProminent)

    Button("undo") {
      service.undo()
    }
    .buttonStyle(.borderedProminent)

    Button("markForDeletion") {
      service.markForDeletion()
    }
    .buttonStyle(.borderedProminent)

    Button("trayRestore") {
      service.trayRestore()
    }
    .buttonStyle(.borderedProminent)

//    Button("confirmDelete") {
//      service.confirmDelete()
//    }
//    .buttonStyle(.borderedProminent)

    Button("sessionComplete") {
      service.sessionComplete()
    }
    .buttonStyle(.borderedProminent)
  }
#endif
