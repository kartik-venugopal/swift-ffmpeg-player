import Foundation

///
/// Encapsulates an ffmpeg AVCodec, AVCodecContext, and AVCodecParameters struct, and provides convenient
/// Swift-style access to their functions and member variables.
///
class Codec {
    
    var pointer: UnsafeMutablePointer<AVCodec>
    var avCodec: AVCodec {pointer.pointee}
    
    var contextPointer: UnsafeMutablePointer<AVCodecContext>?
    var context: AVCodecContext {contextPointer!.pointee}
    
    var paramsPointer: UnsafeMutablePointer<AVCodecParameters>
    var params: AVCodecParameters {paramsPointer.pointee}
    
    var id: UInt32 {avCodec.id.rawValue}
    var name: String {String(cString: avCodec.name)}
    var longName: String {String(cString: avCodec.long_name)}
    
    init(pointer: UnsafeMutablePointer<AVCodec>, contextPointer: UnsafeMutablePointer<AVCodecContext>, paramsPointer: UnsafeMutablePointer<AVCodecParameters>) {
        
        self.pointer = pointer
        self.contextPointer = contextPointer
        self.paramsPointer = paramsPointer
    }
    
    func open() throws {
        
        let codecOpenResult: ResultCode = avcodec_open2(contextPointer, pointer, nil)
        if codecOpenResult.isNonZero {
            
            print("\nCodec.open(): Failed to open codec '\(name)'. Error: \(codecOpenResult.errorDescription))")
            throw DecoderInitializationError(codecOpenResult)
        }
    }
    
    private var destroyed: Bool = false
    
    func destroy() {

        if destroyed {return}

        avcodec_close(contextPointer)
        avcodec_free_context(&contextPointer)

        destroyed = true
    }

    deinit {
        destroy()
    }
}

///
/// A Codec that decodes (encoded) audio data packets into raw (PCM) frames.
///
class AudioCodec: Codec {
    
    var bitRate: Int64 {params.bit_rate}
    var sampleRate: Int32 {params.sample_rate}
    var sampleFormat: SampleFormat = SampleFormat(avFormat: AVSampleFormat(0))
    var channelCount: Int {Int(params.channels)}
    var channelLayout: Int64 = 0
    
    override init(pointer: UnsafeMutablePointer<AVCodec>, contextPointer: UnsafeMutablePointer<AVCodecContext>, paramsPointer: UnsafeMutablePointer<AVCodecParameters>) {
        
        super.init(pointer: pointer, contextPointer: contextPointer, paramsPointer: paramsPointer)
        
        self.sampleFormat = SampleFormat(avFormat: context.sample_fmt)
        
        // Correct channel layout if necessary
        self.channelLayout = context.channel_layout != 0 ? Int64(context.channel_layout) : av_get_default_channel_layout(context.channels)
    }
    
    func printInfo() {
        
        print("\n---------- Codec Info ----------\n")
        
        print(String(format: "Codec Name:    %@", longName))
        print(String(format: "Sample Rate:   %7d", sampleRate))
        print(String(format: "Sample Format: %7@", sampleFormat.name))
        print(String(format: "Sample Size:   %7d", sampleFormat.size))
        print(String(format: "Channels:      %7d", channelCount))
        print(String(format: "Planar ?:      %7@", String(sampleFormat.isPlanar)))
        
        print("---------------------------------\n")
    }
    
    func decode(_ packet: Packet) throws -> [BufferedFrame] {
        
        // Send the packet to the decoder
        var resultCode: Int32 = packet.sendTo(self)
        packet.destroy()

        if resultCode.isNegative {
            
            print("\nCodec.decode(): Failed to decode packet. Error: \(resultCode) \(resultCode.errorDescription))")
            throw DecoderError(resultCode)
        }
        
        // Receive (potentially) multiple frames

        let frame = Frame(sampleFormat: self.sampleFormat)
        var bufferedFrames: [BufferedFrame] = []
        
        resultCode = frame.receiveFrom(self)
        
        // Keep receiving frames while no errors are encountered
        while resultCode.isZero, frame.hasSamples {
            
            bufferedFrames.append(BufferedFrame(frame))
            resultCode = frame.receiveFrom(self)
        }
        
        frame.destroy()
        
        return bufferedFrames
    }
    
    func flushBuffers() {
        avcodec_flush_buffers(contextPointer)
    }
    
    func drain() throws -> [BufferedFrame] {
        
        // Send the "flush packet" to the decoder
        var resultCode: Int32 = avcodec_send_packet(contextPointer, nil)
        
        if resultCode.isNonZero {
            
            print("\nCodec.decode(): Failed to decode packet. Error: \(resultCode) \(resultCode.errorDescription))")
            throw DecoderError(resultCode)
        }
        
        // Receive (potentially) multiple frames
        
        let frame = Frame(sampleFormat: self.sampleFormat)
        var bufferedFrames: [BufferedFrame] = []
        
        resultCode = frame.receiveFrom(self)
        
        // Keep receiving frames while no errors are encountered
        while resultCode.isZero, frame.hasSamples {
            
            bufferedFrames.append(BufferedFrame(frame))
            resultCode = frame.receiveFrom(self)
        }
        
        frame.destroy()
        
        return bufferedFrames
    }
}

///
/// A Codec that reads image data (i.e. cover art).
///
class ImageCodec: Codec {}
