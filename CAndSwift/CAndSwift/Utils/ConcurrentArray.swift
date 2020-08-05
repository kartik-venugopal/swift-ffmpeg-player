import Foundation

class ConcurrentArray<T> {
    
    private var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    var array: [T] = []

    var count: Int {array.count}
    
    subscript(index: Int) -> T {
        
        get {
            
            semaphore.wait()
            defer {semaphore.signal()}
            
            return array[index]
        }
        
        set {
            
            semaphore.wait()
            defer {semaphore.signal()}
            
            array[index] = newValue
        }
    }
    
    func append(_ elm: T) {
        
        semaphore.wait()
        defer {semaphore.signal()}
        
        array.append(elm)
    }
    
    func sort(by comparator: (T, T) -> Bool) {
        
        semaphore.wait()
        defer {semaphore.signal()}
        
        array.sort(by: comparator)
    }
}
