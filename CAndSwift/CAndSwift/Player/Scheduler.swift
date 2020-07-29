import AVFoundation

class Scheduler {
    
    let decoder: Decoder = Decoder()
    let audioEngine: AudioEngine
    
    private var file: AudioFileContext!
    private var codec: AudioCodec! {file.audioCodec}
    
    private var sampleCountForImmediatePlayback: Int32 = 0
    private var sampleCountForDeferredPlayback: Int32 = 0
    
    var audioFormat: AVAudioFormat!
    var scheduledBufferCount: Int = 0
    var eof: Bool {decoder.eof}
    
    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
    }
    
    private let schedulingOpQueue: OperationQueue = {
        
        let queue = OperationQueue()
        queue.underlyingQueue = DispatchQueue.global(qos: .userInitiated)
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()
    
    func initialize(with file: AudioFileContext) throws {
        
        self.file = file
        try decoder.initialize(with: file)
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(codec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        
        let sampleRate: Int32 = codec.sampleRate
        let channelCount: Int32 = codec.params.channels
        let effectiveSampleRate: Int32 = sampleRate * channelCount
        
        switch effectiveSampleRate {
            
        case 0..<100000:
            
            // 44.1 / 48 KHz stereo
            
            sampleCountForImmediatePlayback = 5 * sampleRate
            sampleCountForDeferredPlayback = 10 * sampleRate
            
        case 100000..<500000:
            
            // 96 / 192 KHz stereo
            
            sampleCountForImmediatePlayback = 3 * sampleRate
            sampleCountForDeferredPlayback = 10 * sampleRate
            
        default:
            
            // 96 KHz surround and higher sample rates
            
            sampleCountForImmediatePlayback = 2 * sampleRate
            sampleCountForDeferredPlayback = 7 * sampleRate
        }
    }
    
    func initiateScheduling(from seekPosition: Double? = nil) {
        
        do {
            
            if let theSeekPosition = seekPosition {
                try decoder.seekToTime(theSeekPosition)
            }
            
            scheduleOneBuffer()
            
            let time = measureTime {
                scheduleOneBufferAsync()
            }
            
            print("\nTook \(time * 1000) msec for async scheduling.")
            
        } catch {
            
            if (error as? PacketReadError)?.isEOF ?? false {
                playbackCompleted()
            }
        }
    }
    
    private func scheduleOneBufferAsync() {
        
        if eof {return}
        
        self.schedulingOpQueue.addOperation {
            self.scheduleOneBuffer(sampleCount: self.sampleCountForDeferredPlayback)
        }
    }
    
    private func scheduleOneBuffer(sampleCount: Int32? = nil) {
        
        if eof {return}
        
        let time = measureTime {
            
            do {
            
                if let buffer: SamplesBuffer = try decoder.decode(sampleCount ?? sampleCountForImmediatePlayback), let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
                    
                    audioEngine.scheduleBuffer(audioBuffer, {
                        
                        self.scheduledBufferCount -= 1
                        
                        if !self.audioEngine.hasBeenStopped {
                            
                            if !self.eof {
    
                                self.scheduleOneBufferAsync()
                                print("\nEnqueued one scheduling op ... (\(self.schedulingOpQueue.operationCount))")
    
                            } else if self.scheduledBufferCount == 0 {
    
                                DispatchQueue.main.async {
                                    self.playbackCompleted()
                                }
                            } else {
                                print("\nNOT DOING ANYTHING !!! ... (\(self.scheduledBufferCount))")
                            }
                        }
                    })
                    
                    print("\nScheduled a buffer with \(buffer.frames.count) frames, \(buffer.sampleCount) samples, equaling \(Double(buffer.sampleCount) / Double(codec.sampleRate)) seconds of playback.")
                    
                    // Write out the raw samples to a .raw file for testing in Audacity
                    //            BufferFileWriter.writeBuffer(audioBuffer)
                    //            BufferFileWriter.closeFile()
                    
                    scheduledBufferCount += 1
                    buffer.destroy()
                }
                
            } catch {
                print("\nDecoder threw error: \(error)")
            }
            
            if eof {
                NSLog("Reached EOF !!!")
            }
        }
        
        print("Took \(Int(round(time * 1000))) msec to schedule a buffer\n")
    }
    
    func stop() {
        
        let time = measureTime {
            
            if schedulingOpQueue.operationCount > 0 {
                
                schedulingOpQueue.cancelAllOperations()
                schedulingOpQueue.waitUntilAllOperationsAreFinished()
            }
            
            decoder.playbackStopped()
        }
        
        print("\nSCHEDULER - Waited \(time * 1000) msec for previous ops to stop.")
    }
    
    private func playbackCompleted() {
        
        print("\nSCHEDULER - PC")
        
        self.file = nil
        decoder.playbackCompleted()
        NotificationCenter.default.post(name: .scheduler_playbackCompleted, object: self)
    }
}
