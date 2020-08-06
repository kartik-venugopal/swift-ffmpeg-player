import Foundation

class AudioFileContext {
    
    let file: URL
    
    let format: FormatContext

    let audioStream: AudioStream
    let audioCodec: Codec
    
    var imageStream: ImageStream?
    let imageCodec: Codec?
    
    init?(_ file: URL) {
        
        self.file = file
        
        guard let theFormatContext = FormatContext(file), let audioStream = AudioStream(theFormatContext), let theCodec = Codec(audioStream) else {
            return nil
        }
        
        self.format = theFormatContext
        self.audioStream = audioStream
        self.audioCodec = theCodec
        
        self.imageStream = ImageStream(format)
        
        if let theImageStream = self.imageStream {
            self.imageCodec = Codec(theImageStream)
        } else {
            self.imageCodec = nil
        }
    }
    
    func destroy() {
        
        audioCodec.destroy()
        format.destroy()
    }
    
    deinit {
        destroy()
    }
}
