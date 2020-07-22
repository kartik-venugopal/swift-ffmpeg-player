import Foundation

class FileContext {
    
    let file: URL
    
    let format: FormatContext
    let stream: Stream
    let codec: Codec
    
    init?(_ file: URL) {
        
        self.file = file
        
        guard let theFormatContext = FormatContext(file), let theStream = Stream(theFormatContext), let theCodec = Codec(theStream) else {
            return nil
        }
        
        self.format = theFormatContext
        self.stream = theStream
        self.codec = theCodec
    }
    
    func destroy() {
        
        codec.destroy()
        format.destroy()
    }
    
    deinit {
        destroy()
    }
}
