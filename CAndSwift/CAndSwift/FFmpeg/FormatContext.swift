import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let path: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
    init?(_ file: URL) {
        
        self.file = file
        self.path = file.path
        
        self.pointer = avformat_alloc_context()
        
        if avformat_open_input(&pointer, file.path, nil, nil) >= 0, let pointee = pointer?.pointee {
            self.avContext = pointee
        } else {
            return nil
        }
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        var packet = AVPacket()

        guard av_read_frame(pointer, &packet) > 0 else {throw EOFError()}
        
        return packet.stream_index == stream.index ? Packet(&packet) : nil
    }
}

class Stream {

    var pointer: UnsafeMutablePointer<AVStream>?
    let avStream: AVStream
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>?
    
    init?(_ formatCtx: FormatContext) {
        
        self.index = av_find_best_stream(formatCtx.pointer, AVMEDIA_TYPE_AUDIO, -1, -1, &codecPointer, 0)
        if index == -1 {
            return nil
        }

        self.pointer = formatCtx.avContext.streams.advanced(by: Int(index)).pointee
        if let pointee = self.pointer?.pointee {
            self.avStream = pointee
        } else {
            return nil
        }
    }
}

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

class Packet {
    
    let pointer: UnsafeMutablePointer<AVPacket>
    let avPacket: AVPacket
    
    init(_ pointer: UnsafeMutablePointer<AVPacket>) {
        
        self.pointer = pointer
        self.avPacket = pointer.pointee
    }
}

class Frame {
    
    private var _dataArray: [Data]
    var dataArray: [Data] {_dataArray}

    let channelCount: Int
    let sampleCount: Int32
    let lineSize: Int
    
    init(_ frame: AVFrame) {
        
        self.channelCount = Int(frame.channels)
        self.sampleCount = frame.nb_samples
        self.lineSize = Int(frame.linesize.0)
        
        self._dataArray = []
        
        let buffers = frame.dataPointers
        
        for channelIndex in (0..<8) {
            
            guard let buffer = buffers[channelIndex] else {break}
            _dataArray.append(Data(bytes: buffer, count: lineSize))
        }
    }
}

class DecoderError: Error {
    
    let errorCode: Int32
    
    init(_ code: Int32) {
        self.errorCode = code
    }
    
    var description: String {
        "Unable to decode packet. ErrorCode=\(errorCode)"
    }
}

class EOFError: Error {}
