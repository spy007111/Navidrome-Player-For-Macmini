import SwiftUI

@propertyWrapper
public struct UIState<Value>: DynamicProperty {
    @StateObject private var container: Container
    
    private final class Container: ObservableObject {
        @Published var value: Value
        init(value: Value) { self.value = value }
    }
    
    public init(wrappedValue: Value) {
        _container = StateObject(wrappedValue: Container(value: wrappedValue))
    }
    
    public var wrappedValue: Value {
        get { container.value }
        nonmutating set { container.value = newValue }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { container.value },
            set: { container.value = $0 }
        )
    }
}
