import AVFoundation

///
/// Part of the Player class that handles all audio buffer scheduling-related tasks.
///
extension Player {
    
    ///
    /// A flag indicating whether or not the decoder has reached the end of the currently playing file's audio stream, i.e. EOF..
    ///
    /// This value is used to make decisions about whether or not to continue scheduling and / or to signal completion
    /// of playback.
    ///
    var eof: Bool {decoder.eof}
    
    ///
    /// Initiates decoding and scheduling for the currently chosen audio file, either from the start of the file, or from a given seek position.
    ///
    /// - Parameter seekPosition: An (optional) time value, specified in seconds, denoting a seek position within the
    ///                             currently playing file's audio stream. May be nil. A nil value indicates start decoding
    ///                             and scheduling from the beginning of the stream.
    ///
    /// ```
    /// Each scheduled buffer, when it finishes playing, will recursively decode / schedule one more
    /// buffer. So, in essence, this function initiates a recursive decoding / scheduling loop that
    /// terminates only when there is no more audio to play, i.e. EOF.
    /// ```
    ///
    /// # Notes #
    ///
    /// If the **seekPosition** parameter given is greater than the currently playing file's audio stream duration, this function
    /// will signal completion of playback for the file.
    ///
    func initiateDecodingAndScheduling(from seekPosition: Double? = nil) {
        
        do {
            
            // If a seek position was specified, ask the decoder to seek
            // within the stream.
            if let theSeekPosition = seekPosition {
                
                try decoder.seek(to: theSeekPosition)
                
                // If the seek took the decoder to EOF, signal completion of playback
                // and don't do any scheduling.
                if eof {
                    
                    playbackCompleted()
                    return
                }
            }
            
            // Schedule one buffer for immediate playback
            decodeAndScheduleOneBuffer(maxSampleCount: sampleCountForImmediatePlayback)
            
            // Schedule a second buffer asynchronously, for later, to avoid a gap in playback.
            // If this is not done, when the first buffer finishes playing, there will be
            // a gap in playback equal to the time taken to read/decode the next batch of
            // samples and construct and schedule the next buffer.
            //
            // So, at any given time, while a file is playing, there will always be one
            // extra buffer in the playback queue.
            //
            decodeAndScheduleOneBufferAsync(maxSampleCount: sampleCountForDeferredPlayback)
            
        } catch {
            print("\nDecoder threw error: \(error)")
        }
    }
    
    ///
    /// Asynchronously decodes and schedules a single audio buffer, of the given size (sample count), for playback.
    ///
    /// - Parameter maxSampleCount: The maximum number of samples to be decoded and scheduled for playback.
    ///
    /// # Notes #
    ///
    /// 1. If the decoder has already reached EOF prior to this function being called, nothing will be done. This function will
    /// simply return.
    ///
    /// 2. Since the task is enqueued on an OperationQueue (whose underlying queue is the global DispatchQueue),
    /// this function will not block the caller, i.e. the main thread, while the task executes.
    ///
    private func decodeAndScheduleOneBufferAsync(maxSampleCount: Int32) {
        
        if eof {return}
        
        self.schedulingOpQueue.addOperation {
            self.decodeAndScheduleOneBuffer(maxSampleCount: maxSampleCount)
        }
    }

    ///
    /// Decodes and schedules a single audio buffer, of the given size (sample count), for playback.
    ///
    /// - Parameter maxSampleCount: The maximum number of samples to be decoded and scheduled for playback.
    ///
    /// ```
    /// Delegates to the decoder to decode and buffer a pre-determined (maximum) number of samples.
    ///
    /// Once the decoding is done, an AVAudioPCMBuffer is created from the decoder output, which is
    /// then actually sent to the audio engine for scheduling.
    /// ```
    /// # Notes #
    ///
    /// 1. If the decoder has already reached EOF prior to this function being called, nothing will be done. This function will
    /// simply return.
    ///
    /// 2. If the decoder reaches EOF when invoked from this function call, the number of samples decoded (and subsequently scheduled)
    /// may be less than the maximum sample count specified by the **maxSampleCount** parameter. However, in rare cases, the actual
    /// number of samples may be slightly larger than the maximum, because upon reaching EOF, the decoder will drain the codec's
    /// internal buffers which may result in a few additional samples that will be allowed as this is the terminal buffer.
    ///
    private func decodeAndScheduleOneBuffer(maxSampleCount: Int32) {
        
        if eof {return}
        
        // Ask the decoder to decode up to the given number of samples.
        let frameBuffer: FrameBuffer = decoder.decode(maxSampleCount: maxSampleCount)
        
        let st = CFAbsoluteTimeGetCurrent()
        
        // Transfer the decoded samples into an audio buffer that the audio engine can schedule for playback.
        if let playbackBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameBuffer.sampleCount)) {
            
            let st2 = CFAbsoluteTimeGetCurrent()
            
            if frameBuffer.needsFormatConversion {
                sampleConverter.convert(samplesIn: frameBuffer, andCopyTo: playbackBuffer)
                
            } else {
                frameBuffer.copySamples(to: playbackBuffer)
            }
            
            let end = CFAbsoluteTimeGetCurrent()
            let time = end - st
            print("\nTook \(time * 1000) msec to construct buffer")
            
            let t2 = end - st2
            print("\nTook \(t2 * 1000) msec to convert samples")
            
            // Pass off the audio buffer to the audio engine. The completion handler is executed when
            // the buffer has finished playing.
            //
            // Note that:
            //
            // 1 - the completion handler recursively triggers another decoding / scheduling task.
            // 2 - the completion handler will be invoked by a background thread.
            // 3 - the completion handler will execute even when the player is stopped, i.e. the buffer
            //      has not really completed playback but has been removed from the playback queue.
            
            audioEngine.scheduleBuffer(playbackBuffer, completionHandler: {
                
                // Audio buffer has completed playback, so decrement the counter.
                self.scheduledBufferCount.decrement()
                
                // We don't want the completion handler to do anything if the player has simply been stopped
                // (i.e. no further scheduling is to be done). So, only respond if the player is currently playing.
                if self.state == .playing {
                    
                    if !self.eof {

                        // If EOF has not been reached, continue recursively decoding / scheduling.
                        self.decodeAndScheduleOneBufferAsync(maxSampleCount: self.sampleCountForDeferredPlayback)

                    } else if self.scheduledBufferCount.value == 0 {
                        
                        // EOF has been reached, and all buffers have completed playback.
                        // Signal playback completion (on the main thread).

                        DispatchQueue.main.async {
                            self.playbackCompleted()
                        }
                    }
                }
            })
            
            // Upon scheduling the buffer, increment the counter.
            scheduledBufferCount.increment()
        }
    }
    
    ///
    /// Cancels all (previously queued) decoding / scheduling operations on the OperationQueue, and blocks until they have been terminated.
    ///
    ///  ```
    ///  After calling this function, we can be assured that no unwanted scheduling will take place asynchronously.
    ///
    ///  This condition is important because ...
    ///
    ///  When seeking, for instance, we would want to first stop any previous scheduling tasks
    ///  that were already executing ... before scheduling new buffers from the new seek position. Otherwise, chunks
    ///  of audio from the previous seek position would suddenly start playing.
    ///
    ///  Similarly, when a file is playing and a new file is suddenly chosen for playback, we would want to stop all
    ///  scheduling for the old file and be sure that only audio from the new file would be scheduled.
    ///  ```
    ///
    func stopScheduling() {
        
        if schedulingOpQueue.operationCount > 0 {
            
            schedulingOpQueue.cancelAllOperations()
            schedulingOpQueue.waitUntilAllOperationsAreFinished()
        }
    }
}
