import Foundation
import ffmpeg

class Codec {
    
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVCodec>?
    let avCodec: AVCodec
    
    var contextPointer: UnsafeMutablePointer<AVCodecContext>?
    let context: AVCodecContext
    
    let sampleRate: Int32
    let sampleFormat: AVSampleFormat
    let sampleSize: Int
    let timeBase: AVRational
    
    var avFrame = AVFrame()
    
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
        self.sampleFormat = context.sample_fmt
        self.sampleSize = Int(av_get_bytes_per_sample(sampleFormat))
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
        resultCode = avcodec_receive_frame(contextPointer, &avFrame)

        // Keep receiving frames while no errors are encountered
        while resultCode == 0, avFrame.nb_samples > 0 {
            
            frames.append(Frame(&avFrame, sampleFormat: sampleFormat, sampleSize: sampleSize))
            resultCode = avcodec_receive_frame(contextPointer, &avFrame)
        }
        
        av_frame_unref(&avFrame)
        
        return frames
    }
    
    func destroy() {
        
        // TODO: This crashes when the context has already been automatically destroyed (after playback completion)
        // Can we check something before proceeding ???
        
        if 0 < avcodec_is_open(self.contextPointer) {
            avcodec_close(self.contextPointer)
        }
        
        avcodec_free_context(&self.contextPointer)
    }
    
    func printInfo() {
        
        print("\n---------- Codec Info ----------\n")
        
        print(String(format: "Sample Rate:   %7d", sampleRate))
        print(String(format: "Sample Format: %7@", String(cString: av_get_sample_fmt_name(sampleFormat))))
        print(String(format: "Sample Size:   %7d", sampleSize))
        print(String(format: "Channels:      %7d", context.channels))
        print(String(format: "Planar ?:      %7@", String(av_sample_fmt_is_planar(sampleFormat) == 1)))
        
        print("---------------------------------\n")
    }
}
