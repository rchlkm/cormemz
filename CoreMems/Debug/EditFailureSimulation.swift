// CoreMems/Debug/EditFailureSimulation.swift
#if DEBUG
  import Foundation

  /// Settings switch that makes edits fail on Apply, to exercise the retry flow.
  enum EditFailureSimulation {
    enum Mode: String, CaseIterable, Identifiable {
      case off, once, always
      var id: Self { self }

      var title: String {
        switch self {
        case .off: return "Off"
        case .once: return "First try"
        case .always: return "Every try"
        }
      }
    }

    static let key = "debug.editFailureSimulation"

    private static var failedOnce: Set<String> = []

    static var mode: Mode {
      UserDefaults.standard.string(forKey: key).flatMap(Mode.init(rawValue:)) ?? .off
    }

    /// Whether writing an edit to this asset should fail now.
    static func shouldFail(assetIdentifier: String) -> Bool {
      switch mode {
      case .off: return false
      case .always: return true
      case .once: return failedOnce.insert(assetIdentifier).inserted
      }
    }
  }
#endif
