import Foundation

///
/// A generic FIFO queue data structure.
/// NOTE - This data structure is **not** thread-safe.
///
class Queue<T> {
    
    private var array: [T] = []
    
    func enqueue(_ item: T) {
        array.append(item)
    }
    
    func dequeue() -> T? {
        return array.count > 0 ? array.remove(at: 0) : nil
    }
    
    func dequeueAll() -> [T] {
        
        let copy = array
        array.removeAll()
        return copy
    }
    
    func peek() -> T? {array.first}
    
    func clear() {
        array.removeAll()
    }
    
    var size: Int {array.count}
    
    var isEmpty: Bool {array.isEmpty}
    
    func toArray() -> [T] {
        
        let copy = array
        return copy
    }
}
