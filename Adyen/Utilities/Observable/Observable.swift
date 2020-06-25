//
// Copyright (c) 2019 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Foundation

/// Wraps a value to make it observable.
/// :nodoc:
@propertyWrapper
public final class Observable<ValueType: Equatable>: EventPublisher {
    
    /// Initializes the observable.
    ///
    /// - Parameter value: The initial value.
    public init(_ value: ValueType) {
        self.wrappedValue = value
    }
    
    // MARK: - Value
    
    /// The observable value.
    @available(*, deprecated, message: "Use the Swift 5.1 property wrapper syntax instead.")
    public var value: ValueType {
        get {
            wrappedValue
        }
        
        set {
            wrappedValue = newValue
        }
    }
    
    /// :nodoc:
    public var wrappedValue: ValueType {
        didSet {
            guard wrappedValue != oldValue else { return }
            
            publish(wrappedValue)
        }
    }
    
    // MARK: - Event Publisher
    
    /// The event published by the observable.
    /// Contains the new value.
    public typealias Event = ValueType
    
    /// The event handlers attached to the observable.
    public var eventHandlers = [EventHandlerToken: EventHandler<Event>]()
    
    /// :nodoc:
    public var projectedValue: Observable { self }
    
}
