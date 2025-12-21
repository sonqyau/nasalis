import Combine
import Foundation

@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype Input: ViewModelInput
    associatedtype Output: ViewModelOutputProtocol

    var input: Input { get }
    var output: Output { get }
}

protocol ViewModelInput: Sendable {}

protocol ViewModelOutputProtocol: ObservableObject, Sendable {}
