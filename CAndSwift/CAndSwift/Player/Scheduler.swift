import AVFoundation

extension Player {
    
    func initiateScheduling(from seekPosition: Double? = nil) {
        
        do {
            
            if let theSeekPosition = seekPosition {
                
                try decoder.seekToTime(theSeekPosition)
                
                guard !eof else {
                    
                    playbackCompleted()
                    return
                }
            }
            
            scheduleOneBuffer()
            scheduleOneBufferAsync()
            
        } catch {}
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
                
                let buffer: SamplesBuffer = try decoder.decode(sampleCount ?? sampleCountForImmediatePlayback)
                
                if let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
                    
                    audioEngine.scheduleBuffer(audioBuffer, {
                        
                        self.scheduledBufferCount.decrement()
                        
                        if self.state == .playing {
                            
                            if !self.eof {
    
                                self.scheduleOneBufferAsync()
    
                            } else if self.scheduledBufferCount.value == 0 {
    
                                DispatchQueue.main.async {
                                    self.playbackCompleted()
                                }
                            }
                        }
                    })
                    
                    print("\nScheduled a buffer with \(buffer.frames.count) frames, \(buffer.sampleCount) samples, equaling \(Double(buffer.sampleCount) / Double(codec.sampleRate)) seconds of playback.")
                    
                    // Write out the raw samples to a .raw file for testing in Audacity
                    //            BufferFileWriter.writeBuffer(audioBuffer)
                    //            BufferFileWriter.closeFile()
                    
                    scheduledBufferCount.increment()
                    buffer.destroy()
                }
                
            } catch {
                print("\nDecoder threw error: \(error)")
            }
            
            if eof {
                NSLog("Reached EOF !!!")
            }
        }
        
        print("Took \(Int(round(time * 1000))) msec to schedule the buffer\n")
    }
    
    func stopScheduling() {
        
        if schedulingOpQueue.operationCount > 0 {
            
            schedulingOpQueue.cancelAllOperations()
            schedulingOpQueue.waitUntilAllOperationsAreFinished()
        }
    }
}
