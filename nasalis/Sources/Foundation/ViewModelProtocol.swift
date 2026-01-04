import Combine
import Foundation

@MainActor
protocol ViewModelProtocol: ObservableObject {
  associatedtype Input: ViewModelInput
  associatedtype Output: ViewModelOutput

  var input: Input { get }
  var output: Output { get }
}

protocol ViewModelInput: Sendable {}

protocol ViewModelOutput: ObservableObject, Sendable {}
