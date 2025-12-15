import Combine
import Foundation

@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype Input
    associatedtype Output

    var input: Input { get }

    var output: Output { get }
}

protocol ViewModelInput {}

protocol ViewModelOutput: ObservableObject {}
