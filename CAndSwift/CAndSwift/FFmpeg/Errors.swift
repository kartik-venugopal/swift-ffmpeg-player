import Foundation

class DecoderError: Error {
    
    let errorCode: Int32
    
    init(_ code: Int32) {
        self.errorCode = code
    }
    
    var description: String {
        "Unable to decode packet. ErrorCode=\(errorCode)"
    }
}

class EOFError: Error {}
