import Foundation

///
/// A Codec that decodes (encoded) audio data packets into raw (PCM) frames.
///
class AudioCodec: Codec {
    
    ///
    /// Average bit rate of the encoded data.
    ///
    var bitRate: Int64 {params.bit_rate}
    
    ///
    /// Sample rate of the encoded data (i.e. number of samples per second or Hz).
    ///
    var sampleRate: Int32 {params.sample_rate}
    
    ///
    /// PCM format of the samples.
    ///
    var sampleFormat: SampleFormat = SampleFormat(avFormat: AVSampleFormat(0))
    
    ///
    /// Number of channels of audio data.
    ///
    var channelCount: Int32 = 0
    
    ///
    /// Describes the number and physical / spatial arrangement of the channels. (e.g. "5.1 surround" or "stereo")
    ///
    var channelLayout: Int64 = 0
    
    ///
    /// Instantiates an AudioCodec object, given a pointer to its parameters.
    ///
    /// - Parameter paramsPointer: A pointer to parameters for the associated AVCodec object.
    ///
    override init?(paramsPointer: UnsafeMutablePointer<AVCodecParameters>) {
        
        super.init(paramsPointer: paramsPointer)
        
        self.sampleFormat = SampleFormat(avFormat: context.sample_fmt)
        self.channelCount = params.channels
        
        // Correct channel layout if necessary.
        // NOTE - This is necessary for some files like WAV files that don't specify a channel layout.
        self.channelLayout = context.channel_layout != 0 ? Int64(context.channel_layout) : av_get_default_channel_layout(context.channels)
    }
    
    // TODO: Factor out common code in decode() and drain() into a helper method.
    
    ///
    /// Decodes a single packet and produces (potentially) multiple frames.
    ///
    /// - Parameter packet: The packet that needs to be decoded.
    ///
    /// - returns: An ordered list of frames.
    ///
    /// - throws: **DecoderError** if an error occurs during decoding.
    ///
    func decode(_ packet: Packet) throws -> [BufferedFrame] {
        
        // Send the packet to the decoder for decoding.
        var resultCode: Int32 = packet.sendTo(self)
        
        // The packet may be destroyed at this point as it has already been sent to the codec.
        packet.destroy()

        // If the packet send failed, log a message and throw an error.
        if resultCode.isNegative {
            
            print("\nCodec.decode(): Failed to decode packet. Error: \(resultCode) \(resultCode.errorDescription))")
            throw DecoderError(resultCode)
        }
        
        // Receive (potentially) multiple frames

        // Resuse a single Frame object multiple times.
        let frame = Frame(sampleFormat: self.sampleFormat)
        
        // Collect the received frames in an array.
        var bufferedFrames: [BufferedFrame] = []
        
        // Receive a decoded frame from the codec.
        resultCode = frame.receiveFrom(self)
        
        // Keep receiving frames while no errors are encountered
        while resultCode.isZero, frame.hasSamples {
            
            bufferedFrames.append(BufferedFrame(frame))
            resultCode = frame.receiveFrom(self)
        }
        
        // The frame is no longer needed.
        frame.destroy()
        
        return bufferedFrames
    }
    
    ///
    /// Flush this codec's internal buffers.
    ///
    /// Make sure to call this function prior to seeking within a stream.
    ///
    func flushBuffers() {
        avcodec_flush_buffers(contextPointer)
    }
    
    ///
    /// Drains the codec of all internally buffered frames.
    ///
    /// Call this function after reaching EOF within a stream.
    ///
    /// - throws: **DecoderError** if an error occurs while draining the codec.
    ///
    func drain() throws -> [BufferedFrame] {
        
        // TODO: Do we need to do this whole thing in a while loop ???
        
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
            frame.unreference()
            
            resultCode = frame.receiveFrom(self)
        }
        
        frame.destroy()
        
        return bufferedFrames
    }
    
    ///
    /// Print some codec info to the console.
    /// May be used to verify that the codec was properly read / initialized.
    /// Useful for debugging purposes.
    ///
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
}
