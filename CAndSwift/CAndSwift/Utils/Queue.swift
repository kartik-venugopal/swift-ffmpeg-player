import Foundation

// FIFO
class Queue<T> {
    
    private var array: [T] = []
    
    func enqueue(_ item: T) {
        array.append(item)
    }
    
    func dequeue() -> T? {
        return array.count > 0 ? array.remove(at: 0) : nil
    }
    
    func peek() -> T? {array.first}
    
    func clear() {
        array.removeAll()
    }
    
    var size: Int {array.count}
    
    var isEmpty: Bool {array.count == 0}
    
    func toArray() -> [T] {
        
        let copy = array
        return copy
    }
}
