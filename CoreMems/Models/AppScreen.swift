// CoreMems/Models/AppScreen.swift
import Foundation

enum AppScreen: Equatable {
  case home
  case setup
  case review
  case pendingReview
  case completion
}

/// Progress of applying a confirmed session to the library.
enum CommitState: Equatable {
  case idle
  case committing
  case failed(String)

  var failureMessage: String? {
    if case .failed(let message) = self { return message }
    return nil
  }
}
