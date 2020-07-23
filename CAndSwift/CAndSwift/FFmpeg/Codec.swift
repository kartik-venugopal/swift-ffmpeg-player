import Foundation
import ffmpeg

class Codec {
    
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVCodec>?
    let avCodec: AVCodec
    
    var contextPointer: UnsafeMutablePointer<AVCodecContext>?
    let context: AVCodecContext
    
    let sampleRate: Int32
    let sampleFormat: SampleFormat
    
    let timeBase: AVRational
    
    init?(_ stream: Stream) {
        
        self.filePath = stream.filePath
    
        pointer = stream.codecPointer
        contextPointer = avcodec_alloc_context3(pointer)
        avcodec_parameters_to_context(contextPointer, stream.avStream.codecpar)

        let codecOpenResult = avcodec_open2(contextPointer, pointer, nil)
        guard codecOpenResult == 0, let pointee = pointer?.pointee, let contextPointee = contextPointer?.pointee else {
            
            print("\nCodec.init(): Failed to open codec for file '\(filePath)'. Error: \(errorString(errorCode: codecOpenResult))")
            return nil
        }
        
        self.avCodec = pointee
        self.context = contextPointee
        
        self.sampleRate = context.sample_rate
        self.sampleFormat = SampleFormat(avFormat: context.sample_fmt)
        
        self.timeBase = context.time_base
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
    
    func printInfo() {
        
        print("\n---------- Codec Info ----------\n")
        
        print(String(format: "Sample Rate:   %7d", sampleRate))
        print(String(format: "Sample Format: %7@", sampleFormat.name))
        print(String(format: "Sample Size:   %7d", sampleFormat.size))
        print(String(format: "Channels:      %7d", context.channels))
        print(String(format: "Planar ?:      %7@", String(sampleFormat.isPlanar)))
        
        print("---------------------------------\n")
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
