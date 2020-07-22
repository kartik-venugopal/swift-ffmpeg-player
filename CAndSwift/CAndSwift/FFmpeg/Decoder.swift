import AVFoundation
import ffmpeg

class Decoder {
    
    static let audioEngine: AudioEngine = AudioEngine()
    static var audioFormat: AVAudioFormat!
    static var eof: Bool = false
    static var stopped: Bool = false
    
    static func decodeAndPlay(_ file: URL) {
        
        do {
            
            let fileCtx = try setupForFile(file)
            
            print("\nSuccessfully opened file: \(file.path). File is ready for decoding.")
            fileCtx.stream.printInfo()
            fileCtx.codec.printInfo()
            
            decodeFrames(fileCtx, 5)
            audioEngine.play()

            NSLog("Playback Started !\n")
            decodeFrames(fileCtx, 5)

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
    }
    
    static func setupForFile(_ file: URL) throws -> FileContext {
        
        guard let fileCtx = FileContext(file) else {
            throw DecoderInitializationError()
        }
        
        eof = false
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(fileCtx.codec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
        
        return fileCtx
    }
    
    private static func decodeFrames(_ fileCtx: FileContext, _ seconds: Double = 10) {
        
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        let formatCtx: FormatContext = fileCtx.format
        let stream = fileCtx.stream
        let codec: Codec = fileCtx.codec
        
        let buffer: SamplesBuffer = SamplesBuffer(maxSampleCount: Int32(seconds * Double(codec.sampleRate)))
        
        while !(buffer.isFull || eof) {
            
            do {
                
                if let packet = try formatCtx.readPacket(stream) {
                    
                    let frames: [Frame] = try codec.decode(packet)
                    frames.forEach {buffer.appendFrame(frame: $0)}
                }
                
            } catch {
                
                self.eof = (error as? PacketReadError)?.isEOF ?? self.eof
                break
            }
        }
        
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            audioEngine.scheduleBuffer(audioBuffer, {
                
                if !stopped {
                    eof ? NSLog("Playback completed !!!\n") : decodeFrames(fileCtx)
                }
            })
        }
        
        if eof {
            
            NSLog("Reached EOF !!!")
            fileCtx.destroy()
        }
    }
    
//    static func seekToTime(_ file: URL, _ seconds: Double, _ beginPlayback: Bool) {
//
//        stopped = true
//        if player.playerNode.isPlaying {player.playerNode.stop()}
//        stopped = false
//
//        av_seek_frame(formatCtx, streamIndex, Int64(seconds * timeBase.reciprocal), AVSEEK_FLAG_FRAME)
//
//        decodeFrames(5)
//        player.play()
//        decodeFrames(5)
//    }
}

extension AVRational {

    var ratio: Double {Double(num) / Double(den)}
    var reciprocal: Double {Double(den) / Double(num)}
}
