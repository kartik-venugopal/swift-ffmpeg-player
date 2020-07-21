import AVFoundation
import ffmpeg

class Decoder {
    
    static var formatCtx: UnsafeMutablePointer<AVFormatContext>!
    
    static var streamIndex: Int32 = -1
    static var stream: UnsafeMutablePointer<AVStream>!
    
    static var codec: UnsafeMutablePointer<AVCodec>!
    static var codecCtx: UnsafeMutablePointer<AVCodecContext>!
    
    static var sampleRate: Int32!
    static var sampleFmt: AVSampleFormat!
    static var sampleSize: Int!
    static var timeBase: AVRational!
    
    static let player: Player = Player()
    static var audioFormat: AVAudioFormat!
    static var eof: Bool = false
    
    static func decodeAndPlay(_ file: URL) {
        
        do {
            try setupForFile(file)

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
        
        decodeFrames(5)
        player.play()
        NSLog("Playback Started !\n")
        
        decodeFrames(5)
    }
    
    static func setupForFile(_ file: URL) throws {
        
        formatCtx = avformat_alloc_context()
        
        let path = file.path
        
        if avformat_open_input(&formatCtx, path, nil, nil) < 0 {
            
            print("Couldn't create format for \(path).")
            throw AVError(AVError.operationNotAllowed)
        }
        
        if avformat_find_stream_info(formatCtx, nil) < 0 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        streamIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)
        if streamIndex == -1 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        stream = formatCtx.pointee.streams.advanced(by: Int(streamIndex)).pointee
        
        if let theStream = stream?.pointee {
            
            codecCtx = avcodec_alloc_context3(codec)
            avcodec_parameters_to_context(codecCtx, theStream.codecpar)
            
            if avcodec_open2(codecCtx, codec, nil) < 0 {
                
                print("Couldn't open codec for \(String(cString: avcodec_get_name(codecCtx.pointee.codec_id)))")
                throw AVError(AVError.operationNotAllowed)
            }
            
            sampleRate = codecCtx.pointee.sample_rate
            sampleFmt = codecCtx.pointee.sample_fmt
            sampleSize = Int(av_get_bytes_per_sample(sampleFmt))
            
            // Print stream info
            
            print("---------- Audio Stream Info ----------\n")
            print(String(format: "Stream Index:  %7d", streamIndex))
            print(String(format: "Sample Format: %7@", String(cString: av_get_sample_fmt_name(sampleFmt))))
            print(String(format: "Sample Rate:   %7d", sampleRate))
            print(String(format: "Sample Size:   %7d", av_get_bytes_per_sample(sampleFmt)))
            print(String(format: "Channels:      %7d", codecCtx.pointee.channels))
            print(String(format: "Planar ?:      %7@", String(av_sample_fmt_is_planar(sampleFmt) == 1)))
        }
        
        eof = false
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        player.prepare(audioFormat)
    }
    
    static func decodeFrames(_ seconds: Double = 10) {
        
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        var packet = AVPacket()
        var frame = AVFrame()
        let buffer: SamplesBuffer = SamplesBuffer(maxSampleCount: Int32(seconds * Double(sampleRate)), sampleFmt: sampleFmt, sampleSize: sampleSize)
        
        while !(buffer.isFull || eof) {
            
            guard 0 <= av_read_frame(formatCtx, &packet) else {
                
                eof = true
                break
            }
            defer {
                av_packet_unref(&packet)
            }
            
            if packet.stream_index == streamIndex, let ctx = codecCtx {
                
                decode(ctx: ctx, packet: &packet, frame: &frame, buffer: buffer)
                av_frame_unref(&frame)
            }
        }
        
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            player.scheduleBuffer(audioBuffer, {
                eof ? NSLog("Playback completed !!!\n") : decodeFrames()
            })
        }
        
        if eof {
            
            NSLog("Reached EOF !!!")
            
            av_packet_unref(&packet)
            av_frame_unref(&frame)
            
            if 0 < avcodec_is_open(self.codecCtx) {
                avcodec_close(self.codecCtx)
            }
            avcodec_free_context(&self.codecCtx)
            
            self.codecCtx = nil
            
            avformat_close_input(&self.formatCtx)
            avformat_free_context(self.formatCtx)
        }
    }
    
    static func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>, frame: UnsafeMutablePointer<AVFrame>?, buffer: SamplesBuffer) {
        
        var resultCode: Int32 = avcodec_send_packet(ctx, packet)
        av_packet_unref(packet)
        
        if resultCode < 0 {
            
            print("err:", resultCode)
            return
        }
        
        resultCode = avcodec_receive_frame(ctx, frame)
        
        while resultCode == 0, frame!.pointee.nb_samples > 0 {
            
            buffer.appendFrame(frame: frame!)
            resultCode = avcodec_receive_frame(ctx, frame)
        }
    }
}

