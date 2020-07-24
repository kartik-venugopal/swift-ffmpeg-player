import AVFoundation
import ffmpeg

class Player {
    
    let audioEngine: AudioEngine = AudioEngine()
    var audioFormat: AVAudioFormat!
    var eof: Bool = false
    
    var scheduledBufferCount: Int = 0
    
    var playingFile: AudioFileContext?
    
    var state: PlayerState = .stopped
    
    var volume: Float {
        
        get {audioEngine.volume}
        set {audioEngine.volume = min(1, max(0, newValue))}
    }
    
    var seekPosition: Double {audioEngine.seekPosition}
    
    func togglePlayPause() {
        
        audioEngine.pauseOrResume()
        state = audioEngine.isPlaying ? .playing : .paused
    }
    
    func decodeAndPlay(_ file: URL) {
        
        stop()
        
        do {
            
            let fileCtx = try setupForFile(file)
            playingFile = fileCtx
            
            print("\nSuccessfully opened file: \(file.path). File is ready for decoding.")
            fileCtx.audioStream.printInfo()
            fileCtx.audioCodec.printInfo()
            
            if !fileCtx.audioCodec.open() {return}
            
            var time = measureTime {
                decodeFrames(fileCtx, 5)
            }
            
            print("\nTook \(Int(round(time * 1000))) msec to decode 5 seconds")

            audioEngine.seekTo(0)
            audioEngine.play()
            state = .playing

            NSLog("Playback Started !\n")

            time = measureTime {
                decodeFrames(fileCtx, 5)
            }

            print("\nTook \(Int(round(time * 1000))) msec to decode another 5 seconds")

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
    }
    
    func stop(_ playbackFinished: Bool = true) {
        
        state = .stopped
        audioEngine.stop()
        
        if playbackFinished {
            playingFile = nil
        }
    }
    
    func setupForFile(_ file: URL) throws -> AudioFileContext {
        
        guard let fileCtx = AudioFileContext(file) else {throw DecoderInitializationError()}
        
        eof = false
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(fileCtx.audioCodec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
        
        return fileCtx
    }
    
    private func decodeFrames(_ fileCtx: AudioFileContext, _ seconds: Double = 10) {
        
        print()
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        let formatCtx: FormatContext = fileCtx.format
        let stream = fileCtx.audioStream
        let codec: AudioCodec = fileCtx.audioCodec
        
        let buffer: SamplesBuffer = SamplesBuffer(sampleFormat: codec.sampleFormat, maxSampleCount: Int32(seconds * Double(codec.sampleRate)))
        
        while !(buffer.isFull || eof) {
            
            do {
                
                if let packet = try formatCtx.readPacket(stream) {
                    for frame in try codec.decode(packet) {
                        buffer.appendFrame(frame: frame)
                    }
                }
                
            } catch {
                
                // TODO: Possibility of infinite loop with continuous errors suppressed here.
                // Maybe set a maximum consecutive error limit ??? eg. If 3 consecutive errors are encountered, then break from the loop.
                if (error as? PacketReadError)?.isEOF ?? false {
                    self.eof = true
                }
            }
        }
        
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            audioEngine.scheduleBuffer(audioBuffer, {

                self.scheduledBufferCount -= 1

                if self.state != .stopped {

                    if !self.eof {

                        let time = measureTime {
                            self.decodeFrames(fileCtx)
                        }

                        NSLog("Decoded 10 seconds of audio in \(Int(round(time * 1000))) msec\n")

                    } else if self.scheduledBufferCount == 0 {
                        
                        NSLog("Playback completed !!!\n")
                        DispatchQueue.main.async {
                            self.stop()
                        }
                    }
                }
            })
            
            // Write out the raw samples to a .raw file for testing in Audacity
//            BufferFileWriter.writeBuffer(audioBuffer)
//            BufferFileWriter.closeFile()
            
            scheduledBufferCount += 1
        }
        
        if eof {
            
            NSLog("Reached EOF !!!")
            fileCtx.destroy()
        }
    }
    
    func seekToTime(_ file: URL, _ seconds: Double, _ beginPlayback: Bool = true) {
        
        if let thePlayingFile = playingFile {

            stop(false)
            
            print("\nTimeBase: \(thePlayingFile.audioStream.timeBase.num) / \(thePlayingFile.audioStream.timeBase.den)")
            
            av_seek_frame(thePlayingFile.format.pointer, thePlayingFile.audioStream.index, Int64(seconds * thePlayingFile.audioStream.timeBase.reciprocal), AVSEEK_FLAG_FRAME)
            
            decodeFrames(thePlayingFile, 5)

            audioEngine.seekTo(seconds)
            audioEngine.play()
            state = .playing
            
            decodeFrames(thePlayingFile, 5)
        }

//        decodeFrames(5)
//        player.play()
//        decodeFrames(5)
    }
}

enum PlayerState {
    
    // Not playing any track
    case stopped
    
    // Playing a track
    case playing
    
    // Paued while playing a track
    case paused
}

extension AVRational {

    var ratio: Double {Double(num) / Double(den)}
    var reciprocal: Double {Double(den) / Double(num)}
}
