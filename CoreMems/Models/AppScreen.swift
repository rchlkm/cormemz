// CoreMems/Models/AppScreen.swift
import Foundation

enum AppScreen: Equatable {
  case home
  case setup
  case browse
  case pendingChanges
  case completion
}

/// Progress of applying a confirmed session to the library.
enum ApplyState: Equatable {
  case idle
  case applying
  case failed(String)

  var failureMessage: String? {
    if case .failed(let message) = self { return message }
    return nil
  }
}
