import Foundation

///
/// Encapsulates an ffmpeg AVPacket struct that represents a single packet
/// i.e. audio data in its encoded / compressed form, prior to decoding,
/// and provides convenient Swift-style access to their functions and member variables.
///
class Packet {
    
    ///
    /// The encapsulated AVPacket object.
    ///
    var avPacket: AVPacket
    
    ///
    /// Index of the stream from which this packet was read.
    ///
    var streamIndex: Int32 {avPacket.stream_index}
    
    ///
    /// Size, in bytes, of this packet's data.
    ///
    var size: Int32 {avPacket.size}
    
    ///
    /// Duration of the packet's samples, specified in the source stream's time base units.
    ///
    var duration: Int64 {avPacket.duration}
    
    ///
    /// Offset position of the packet, in bytes, from the start of the stream.
    ///
    var bytePosition: Int64 {avPacket.pos}
    
    ///
    /// Presentation timestamp (PTS) of this packet, specified in the source stream's time base units.
    ///
    var pts: Int64 {avPacket.pts}
    
    ///
    /// The raw data (unsigned bytes) contained in this packet.
    ///
    var rawData: UnsafeMutablePointer<UInt8>! {avPacket.data}
    
    ///
    /// The raw data encapsulated in a byte buffer, if there is any raw data. Nil if there is no raw data.
    ///
    var data: Data? {
        
        if let theData = rawData, size > 0 {
            return Data(bytes: theData, count: Int(size))
        }
        
        return nil
    }
    
    ///
    /// Instantiates a Packet from a format context (container), if it can be read. Returns nil otherwise.
    ///
    /// - Parameter formatCtx: The format context (container) from which to read a packet.
    ///
    /// - throws: **PacketReadError** if the read fails.
    ///
    init(fromFormat formatCtx: UnsafeMutablePointer<AVFormatContext>?) throws {
        
        self.avPacket = AVPacket()
        
        // Try to read a packet.
        let readResult: Int32 = av_read_frame(formatCtx, &avPacket)
        
        // If the read fails, log a message and throw an error.
        guard readResult >= 0 else {
            
            // No need to log a message for EOF as it is considered harmless.
            if !isEOF(code: readResult) {
                print("\nPacket.init(): Unable to read packet. Error: \(readResult) (\(readResult.errorDescription)))")
            }
            
            throw PacketReadError(readResult)
        }
    }
    
    ///
    /// Instantiates a Packet from an AVPacket that has already been read from the source stream.
    ///
    /// - Parameter avPacket: A pre-existing AVPacket that has already been read.
    ///
    init(encapsulating avPacket: AVPacket) {
        
        self.avPacket = avPacket
        
        // Since this avPacket was not allocated by this object, we
        // cannot deallocate it here. It is the caller's responsibility
        // to ensure that avPacket is destroyed.
        //
        // So, set the destroyed flag, to prevent deallocation.
        destroyed = true
    }

    ///
    /// Sends this packet to a codec for decoding.
    ///
    /// - Parameter codec: The codec that will decode this packet.
    ///
    /// - returns: An integer code indicating the result of the send operation.
    ///
    func send(to codec: Codec) -> ResultCode {
        return avcodec_send_packet(codec.contextPointer, &avPacket)
    }

    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false
    
    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized or is no longer needed.
    ///
    func destroy() {

        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}
        
        av_packet_unref(&avPacket)
        av_freep(&avPacket)
        
        destroyed = true
    }
    
    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}
