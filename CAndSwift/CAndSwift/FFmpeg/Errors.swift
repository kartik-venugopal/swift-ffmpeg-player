import Foundation

typealias ResultCode = Int32

extension ResultCode {

    var errorDescription: String {
        
        if self == 0 {
            return "No error"
            
        } else {
            
            let errString = UnsafeMutablePointer<Int8>.allocate(capacity: 100)
            return av_strerror(self, errString, 100) == 0 ? String(cString: errString) : "Unknown error"
        }
    }
    
    var isNonNegative: Bool {self >= 0}
    var isNonPositive: Bool {self <= 0}
    
    var isPositive: Bool {self > 0}
    var isNegative: Bool {self < 0}
    
    var isZero: Bool {self == 0}
    var isNonZero: Bool {self != 0}
}

class CodedError: Error {
    
    let code: ResultCode
    
    var isEOF: Bool {code == EOF_CODE}
    var description: String {code.errorDescription}
    
    init(_ code: ResultCode) {
        self.code = code
    }
}

class DecoderError: CodedError {
    static let eof: DecoderError = DecoderError(EOF_CODE)
}

class PacketReadError: CodedError {
    static let eof: PacketReadError = PacketReadError(EOF_CODE)
}

class SeekError: CodedError {}

class DecoderInitializationError: CodedError {}

class PlayerInitializationError: Error {}
