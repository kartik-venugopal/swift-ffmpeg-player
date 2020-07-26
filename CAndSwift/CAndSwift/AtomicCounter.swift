import Foundation

public final class AtomicCounter<T> where T: SignedInteger {
    
    private let lock = DispatchSemaphore(value: 1)
    private var _value: T
    
    public init(value initialValue: T = 0) {
        _value = initialValue
    }
    
    public var value: T {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
    
    public func decrementAndGet() -> T {
        lock.wait()
        defer { lock.signal() }
        _value -= 1
        return _value
    }
    
    public func incrementAndGet() -> T {
        lock.wait()
        defer { lock.signal() }
        _value += 1
        return _value
    }
    
    public func add(_ addend: T) {
        
        lock.wait()
        defer { lock.signal() }
        _value += addend
    }
}
