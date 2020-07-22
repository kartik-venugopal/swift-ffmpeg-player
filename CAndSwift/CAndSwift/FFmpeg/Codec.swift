import Foundation
import ffmpeg

class Codec {
    
    var pointer: UnsafeMutablePointer<AVCodec>?
    let avCodec: AVCodec
    
    let contextPointer: UnsafeMutablePointer<AVCodecContext>
    let context: AVCodecContext
    
    let sampleRate: Int32
    let sampleFormat: AVSampleFormat
    let sampleSize: Int
    let timeBase: AVRational
    
    init?(_ stream: Stream) {
    
        contextPointer = avcodec_alloc_context3(pointer)
        avcodec_parameters_to_context(contextPointer, stream.avStream.codecpar)

        guard avcodec_open2(contextPointer, pointer, nil) == 0, let pointee = pointer?.pointee else {
            return nil
        }
        
        self.avCodec = pointee
        self.context = contextPointer.pointee
        
        self.sampleRate = context.sample_rate
        self.sampleFormat = context.sample_fmt
        self.sampleSize = Int(av_get_bytes_per_sample(sampleFormat))
        self.timeBase = context.time_base
    }
    
    func decode(_ packet: Packet) throws -> [Frame] {
        
        // Send the packet to the decoder
        
        var resultCode: Int32 = avcodec_send_packet(contextPointer, packet.pointer)
        av_packet_unref(packet.pointer)

        if resultCode < 0 {
            throw DecoderError(resultCode)
        }
        
        // Receive (potentially) multiple frames

        var frames: [Frame] = []
        var avFrame = AVFrame()
        resultCode = avcodec_receive_frame(contextPointer, &avFrame)

        // Keep receiving frames while no errors are encountered
        
        while resultCode == 0, avFrame.nb_samples > 0 {
            
            frames.append(Frame(avFrame))
            resultCode = avcodec_receive_frame(contextPointer, &avFrame)
        }
        
        av_frame_unref(&avFrame)
        
        return frames
    }
}
