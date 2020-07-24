import Foundation
import ffmpeg

class Codec {
    
    var pointer: UnsafeMutablePointer<AVCodec>
    let avCodec: AVCodec
    
    var contextPointer: UnsafeMutablePointer<AVCodecContext>?
    let context: AVCodecContext
    
    var name: String {String(cString: avCodec.name)}
    
    init(pointer: UnsafeMutablePointer<AVCodec>, contextPointer: UnsafeMutablePointer<AVCodecContext>) {
        
        self.pointer = pointer
        self.avCodec = pointer.pointee
        
        self.contextPointer = contextPointer
        self.context = contextPointer.pointee
    }
    
    func open() -> Bool {
        
        let codecOpenResult = avcodec_open2(contextPointer, pointer, nil)

        if codecOpenResult != 0 {
            print("\nCodec.open(): Failed to open codec '\(name)'. Error: \(errorString(errorCode: codecOpenResult))")
        }
        
        return codecOpenResult == 0
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        
        // TODO: This crashes when the context has already been automatically destroyed (after playback completion)
        // Can we check something before proceeding ???
        
        if 0 < avcodec_is_open(self.contextPointer) {
            avcodec_close(self.contextPointer)
        }
        
        avcodec_free_context(&self.contextPointer)
        
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}

class AudioCodec: Codec {
    
    let sampleRate: Int32
    let sampleFormat: SampleFormat
    let timeBase: AVRational
    
    override init(pointer: UnsafeMutablePointer<AVCodec>, contextPointer: UnsafeMutablePointer<AVCodecContext>) {
        
        self.sampleRate = contextPointer.pointee.sample_rate
        self.sampleFormat = SampleFormat(avFormat: contextPointer.pointee.sample_fmt)
        self.timeBase = contextPointer.pointee.time_base
        
        super.init(pointer: pointer, contextPointer: contextPointer)
    }
    
    func printInfo() {
        
        print("\n---------- Codec Info ----------\n")
        
        print(String(format: "Sample Rate:   %7d", sampleRate))
        print(String(format: "Sample Format: %7@", sampleFormat.name))
        print(String(format: "Sample Size:   %7d", sampleFormat.size))
        print(String(format: "Channels:      %7d", context.channels))
        print(String(format: "Planar ?:      %7@", String(sampleFormat.isPlanar)))
        
        print("---------------------------------\n")
    }
    
    func decode(_ packet: Packet) throws -> [Frame] {
        
        // Send the packet to the decoder
        var resultCode: Int32 = avcodec_send_packet(contextPointer, packet.pointer)
        packet.destroy()

        if resultCode < 0 {
            
            print("\nCodec.decode(): Failed to decode packet. Error: \(errorString(errorCode: resultCode))")
            throw DecoderError(resultCode)
        }
        
        // Receive (potentially) multiple frames

        var frames: [Frame] = []
        var avFrame = AVFrame()
        
        resultCode = avcodec_receive_frame(contextPointer, &avFrame)

        // Keep receiving frames while no errors are encountered
        while resultCode == 0, avFrame.nb_samples > 0 {
            
            frames.append(Frame(&avFrame, sampleFormat: sampleFormat))
            resultCode = avcodec_receive_frame(contextPointer, &avFrame)
        }
        
        av_frame_unref(&avFrame)
        
        return frames
    }
}

class ImageCodec: Codec {
    
}
