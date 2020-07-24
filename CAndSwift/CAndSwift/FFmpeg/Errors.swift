import Foundation

class DecoderError: Error {
    
    let errorCode: Int32
    
    init(_ code: Int32) {
        self.errorCode = code
    }
    
    var description: String {
        "Unable to decode packet. Error: \(errorCode) (\(errorString(errorCode: errorCode)))"
    }
}

class PacketReadError: Error {
    
    let errorCode: Int32
    
    // TODO: Use constant AVERROR_EOF instead
    var isEOF: Bool {errorCode == -541478725}
    
    init(_ code: Int32) {
        self.errorCode = code
    }
}

class SeekError: Error {
    
    let errorCode: Int32
    
    // TODO: Use constant AVERROR_EOF instead
    var isEOF: Bool {errorCode == -541478725}
    
    init(_ code: Int32) {
        self.errorCode = code
    }
}

class DecoderInitializationError: Error {}

func errorString(errorCode: Int32) -> String {
    
    if errorCode == 0 {
        return "No error"
        
    } else {
        
        let errString = UnsafeMutablePointer<Int8>.allocate(capacity: 100)
        return av_strerror(errorCode, errString, 100) == 0 ? String(cString: errString) : "UNKNOWN_ERROR"
    }
}
