import AVFoundation

extension Player {
    
    func initiateScheduling(from seekPosition: Double? = nil) {
        
        do {
            
            if let theSeekPosition = seekPosition {
                
                try decoder.seekToTime(theSeekPosition)
                
                if eof {
                    
                    playbackCompleted()
                    return
                }
            }
            
            scheduleOneBuffer()
            scheduleOneBufferAsync()
            
        } catch {
            print("\nDecoder threw error: \(error)")
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
                
                scheduledBufferCount.increment()
                buffer.destroy()
            }
            
        } catch {
            print("\nDecoder threw error: \(error)")
        }
    }
    
    func stopScheduling() {
        
        if schedulingOpQueue.operationCount > 0 {
            
            schedulingOpQueue.cancelAllOperations()
            schedulingOpQueue.waitUntilAllOperationsAreFinished()
        }
    }
}
