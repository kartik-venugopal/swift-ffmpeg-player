import AVFoundation
import ffmpeg

class Player {
    
    let audioEngine: AudioEngine = AudioEngine()
    var audioFormat: AVAudioFormat!
    var eof: Bool = false
    var stopped: Bool = false
    
    var scheduledBufferCount: Int = 0
    
    var playingFile: FileContext?
    
    func decodeAndPlay(_ file: URL) {
        
        stop()
        
        do {
            
            let fileCtx = try setupForFile(file)
            playingFile = fileCtx
            
            print("\nSuccessfully opened file: \(file.path). File is ready for decoding.")
            fileCtx.stream.printInfo()
            fileCtx.codec.printInfo()
            
            var time = measureTime {
                decodeFrames(fileCtx, 5)
            }
            
            print("\nTook \(time * 1000) msec to decode 5 seconds")
            
            audioEngine.play()

            NSLog("Playback Started !\n")
            
            time = measureTime {
                decodeFrames(fileCtx, 5)
            }

            print("\nTook \(time * 1000) msec to decode another 5 seconds")

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
    }
    
    func stop() {
        
        stopped = true
        audioEngine.stop()
        stopped = false
        
        if playingFile != nil {
            playingFile = nil
        }
    }
    
    func setupForFile(_ file: URL) throws -> FileContext {
        
        guard let fileCtx = FileContext(file) else {throw DecoderInitializationError()}
        
        eof = false
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(fileCtx.codec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
        
        return fileCtx
    }
    
    private func decodeFrames(_ fileCtx: FileContext, _ seconds: Double = 10) {
        
        print()
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        let formatCtx: FormatContext = fileCtx.format
        let stream = fileCtx.stream
        let codec: Codec = fileCtx.codec
        
        let buffer: SamplesBuffer = SamplesBuffer(maxSampleCount: Int32(seconds * Double(codec.sampleRate)))
        
        while !(buffer.isFull || eof) {
            
            do {
                
                if let packet = try formatCtx.readPacket(stream) {
                    for frame in try codec.decode(packet) {
                        buffer.appendFrame(frame: frame)
                    }
                }
                
            } catch {
                
                self.eof = (error as? PacketReadError)?.isEOF ?? self.eof
                break
            }
        }
        
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            audioEngine.scheduleBuffer(audioBuffer, {

                self.scheduledBufferCount -= 1

                if !self.stopped {

                    if !self.eof {
                        
                        let time = measureTime {
                            self.decodeFrames(fileCtx)
                        }
                        
                        NSLog("Decoded 10 seconds of audio in \(time * 1000) msec\n")

                    } else if self.scheduledBufferCount == 0 {
                        NSLog("Playback completed !!!\n")
                    }
                }
            })
            
            // Write out the first 35 seconds of audio to .raw file for testing in Audacity
//            if BufferFileWriter.ctr < (35 * codec.sampleRate) {
//                BufferFileWriter.writeBuffer(audioBuffer)
//                BufferFileWriter.closeFile()
//            } else {
//BufferFileWriter.closeFile()
//            }
            
            scheduledBufferCount += 1
        }
        
        if eof {
            
            NSLog("Reached EOF !!!")
            fileCtx.destroy()
        }
    }
    
//    func seekToTime(_ file: URL, _ seconds: Double, _ beginPlayback: Bool) {
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
