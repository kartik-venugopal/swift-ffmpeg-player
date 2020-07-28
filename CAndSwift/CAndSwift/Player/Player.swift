import AVFoundation

class Player {
    
    let audioEngine: AudioEngine = AudioEngine()
    var audioFormat: AVAudioFormat!
    
    // TODO: Move this flag to the audio stream or codec
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
    
    private let initialBufferDuration: Double = 5
    
    private let schedulingOpQueue: OperationQueue = {

        let queue = OperationQueue()
        queue.underlyingQueue = DispatchQueue.global(qos: .userInitiated)
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()

    init() {
        
        // Hack to eagerly initialize a lazy variable (so that the resampler is ready to go when required)
        _ = Resampler.instance
    }
    
    func play(_ file: URL) {
        
        stopAndWait()
        
        do {
            
            let fileCtx = try setupForFile(file)
            playingFile = fileCtx
            
            print("\nSuccessfully opened file: \(file.path). File is ready for decoding.")
            fileCtx.audioStream.printInfo()
            fileCtx.audioCodec.printInfo()
            
            if !fileCtx.audioCodec.open() {
                
                print("\nUnable to open audio codec for file: \(file.path). Aborting playback.")
                return
            }
            
            scheduleOneBuffer(fileCtx, initialBufferDuration)
            
            beginPlayback(0)
            
            self.schedulingOpQueue.addOperation {
                self.scheduleOneBuffer(fileCtx, self.initialBufferDuration)
            }
            
            print("\nEnqueued one scheduling op ... (\(self.schedulingOpQueue.operationCount))")

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
    }
    
    func beginPlayback(_ seekTime: Double) {

        audioEngine.seekTo(seekTime)
        audioEngine.play()
        state = .playing
    }
    
    func stop(_ playbackFinished: Bool = true) {
        
        state = .stopped
        audioEngine.stop()
        
        if playbackFinished {
            
            playingFile = nil
            audioEngine.playbackCompleted()
        }
    }
    
    func stopAndWait(_ playbackFinished: Bool = true) {
        
        stop(playbackFinished)
        
        let time = measureTime {
            
            if schedulingOpQueue.operationCount > 0 {
                
                schedulingOpQueue.cancelAllOperations()
                schedulingOpQueue.waitUntilAllOperationsAreFinished()
            }
        }
        
        print("\nWaited \(time * 1000) msec for previous ops to stop.")
    }
    
    func setupForFile(_ file: URL) throws -> AudioFileContext {
        
        guard let fileCtx = AudioFileContext(file) else {throw DecoderInitializationError()}
        
        eof = false
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(fileCtx.audioCodec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
        
        return fileCtx
    }
    
    // TODO
    private var overflowFrames: [BufferedFrame] = []
    
    private func scheduleOneBuffer(_ fileCtx: AudioFileContext, _ seconds: Double = 10) {
        
        let time = measureTime {
        
        let formatCtx: FormatContext = fileCtx.format
        let stream = fileCtx.audioStream
        let codec: AudioCodec = fileCtx.audioCodec
        
        let buffer: SamplesBuffer = SamplesBuffer(sampleFormat: codec.sampleFormat,
                                                      maxSampleCount: min(Resampler.maxSamplesPerBuffer,  Int32(seconds * Double(codec.sampleRate))))
        
        while !(buffer.isFull || eof) {
            
            do {
                
                if let packet = try formatCtx.readPacket(stream) {
                    
                    // TODO: What if buffer fills up during the middle of this loop ?
                    // Need to reject any excess "overflow" frames and store them for later.
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
        
        print("----------------------------- BEGIN -----------------------------")
        
//        print("\nPkt Read Time: \(Int(round(fileCtx.format.readTime * 1000))) msec")
//        print("\nDecode-Send Time: \(Int(round(fileCtx.audioCodec.sendTime * 1000))) msec")
//        print("\nDecode-Rcv Time: \(Int(round(fileCtx.audioCodec.rcvTime * 1000))) msec")
        
        fileCtx.format.readTime = 0
        fileCtx.audioCodec.sendTime = 0
        fileCtx.audioCodec.rcvTime = 0
            
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            audioEngine.scheduleBuffer(audioBuffer, {

                self.scheduledBufferCount -= 1

                if self.state != .stopped {

                    if !self.eof {

                        self.schedulingOpQueue.addOperation {
                            self.scheduleOneBuffer(fileCtx)
                        }
                        
                        print("\nEnqueued one scheduling op ... (\(self.schedulingOpQueue.operationCount))")

                    } else if self.scheduledBufferCount == 0 {

                        DispatchQueue.main.async {
                            self.playbackCompleted()
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
        }
            
        buffer.destroy()
            
        }
        
        print("\nTook \(Int(round(time * 1000))) msec to schedule \(seconds) seconds")
        
        print("\n----------------------------- END -----------------------------\n")
    }
    
    private func playbackCompleted() {
        
        NSLog("Playback completed !!!\n")
        
        stop()
        audioEngine.playbackCompleted()
        playingFile?.destroy()
        
        NotificationCenter.default.post(name: .playbackCompleted, object: self)
    }
    
    // TODO: Why doesn't seeking work for high sample rate FLAC files ? (32-bit integer interleaved)
    func seekToTime(_ seconds: Double, _ shouldBeginPlayback: Bool = true) {
        
        // BUG: After EOF is reached (but track is still playing last few seconds),
        // it should still be possible to seek backwards.
        
        if let thePlayingFile = playingFile {

            stopAndWait(false)
            
            do {
                
                try thePlayingFile.format.seekWithinStream(thePlayingFile.audioStream, seconds)
                
                // TODO: Check how much seek time is remaining (i.e. duration - seekPos)
                // and set the buffer size accordingly. Don't schedule the 2nd buffer unless necessary.
                
                scheduleOneBuffer(thePlayingFile, 5)
                
                shouldBeginPlayback ? beginPlayback(seconds) : audioEngine.seekTo(seconds)
                
                // TODO: Check for EOF before scheduling another buffer
                self.schedulingOpQueue.addOperation {
                    self.scheduleOneBuffer(thePlayingFile, 5)
                }
                
            } catch {
                
                if let seekError = error as? SeekError, seekError.isEOF {
                    playbackCompleted()
                }
            }
        }
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
