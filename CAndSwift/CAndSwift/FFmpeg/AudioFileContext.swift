import Foundation

class AudioFileContext {
    
    let file: URL
    
    let format: FormatContext

    let audioStream: AudioStream
    let audioCodec: AudioCodec
    
    init?(_ file: URL) {
        
        self.file = file
        
        
        guard let theFormatContext = FormatContext(file, [AVMEDIA_TYPE_AUDIO]), let audioStream = theFormatContext.audioStream else {
            return nil
        }
        
        self.format = theFormatContext
        self.audioStream = audioStream
        self.audioCodec = audioStream.codec
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}

        audioCodec.destroy()
        format.destroy()
        
        destroyed = true
    }

    deinit {
        destroy()
    }
}
