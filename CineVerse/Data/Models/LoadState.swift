import Foundation

public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    public var value: Value? {
        if case .loaded(let val) = self { return val }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

extension LoadState: Equatable where Value: Equatable {}
