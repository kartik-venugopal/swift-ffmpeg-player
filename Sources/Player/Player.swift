import AVFoundation

///
/// Facade for all high-level playback functions - play / pause / stop / seeking / volume control.
/// Suitable for direct use by a user interface.
///
class Player {
    
    /// A helper object that manages the underlying audio engine.
    let audioEngine: AudioEngine = AudioEngine()

    /// The current playback state of the player
    var state: PlayerState = .stopped
    
    ///
    /// The number of audio buffers currently scheduled for playback by the player.
    ///
    /// Used to determine:
    /// 1. when playback has completed.
    /// 2. whether or not a scheduling task was successful and whether or not playback should begin.
    ///
    var scheduledBufferCount: AtomicCounter<Int> = AtomicCounter<Int>()
    
    ///
    /// A context associated with the currently playing file.
    /// May be nil (if no file is currently playing).
    ///
    var playingFile: AudioFileContext!
    
    var decoder: FFmpegDecoder! {playingFile?.decoder}
    
    ///
    /// A **serial** operation queue on which all *deferred* scheduling tasks are enqueued, i.e. tasks scheduling buffers that will be played back at a later time.
    ///
    /// ```
    /// The use of this queue allows monitoring and cancellation of scheduling tasks
    /// (e.g. when seeking invalidates previous scheduling tasks).
    /// ```
    /// # Notes #
    ///
    /// 1. Uses the global dispatch queue.
    ///
    /// 2. This is a *serial* queue, meaning that only one operation can execute at any given time. This is very important, because we don't want a race condition when scheduling buffers.
    ///
    /// 3. Scheduling tasks for *immediate* playback will **not** be enqueued on this queue. They will be run immediately on the main thread.
    ///
    let schedulingOpQueue: OperationQueue = {
        
        let queue = OperationQueue()
        queue.underlyingQueue = DispatchQueue.global(qos: .userInitiated)
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()
    
    ///
    /// Property to adjust the player's volume.
    /// Must be a floating-point value between 0 and 1.
    ///
    var volume: Float {
        
        get {audioEngine.volume}
        set {audioEngine.volume = min(1, max(0, newValue))}
    }
    
    ///
    /// Seek position (in seconds) from which playback for the currently playing file started.
    ///
    /// # Notes #
    ///
    /// 1. If no seeks are performed, this will be 0, denoting the start of the track.
    ///
    /// 2. Every time a seek is performed, this variable will be set to the new seek time.
    ///
    var playbackStartPosition: Double = 0
    
    ///
    /// Accesses the player's current seek position within the currently playing file (in seconds).
    ///
    /// ```
    /// Uses the audio engine's seek position (number of frames played) and
    /// playbackStartPosition to compute the current seek position.
    /// ```
    ///
    var seekPosition: Double {
        
        if playingFile == nil {return 0}
        
        return playbackStartPosition + (Double(audioEngine.framePosition) / playingFile.audioFormat.sampleRate)
    }

    ///
    /// Initiates playback of an audio file, given its context.
    ///
    /// - Parameter fileCtx: A context through which decoding of the audio file can be performed.
    ///
    /// # Notes #
    ///
    /// Fails (does nothing) if
    /// 1 - initialization of the appropriate codec fails, OR
    /// 2 - preparation of the audio engine fails.
    ///
    func play(fileContext: AudioFileContext) {
        
        // Reset player and decoder state before playback.
        playbackCompleted(false)
        playingFile = fileContext
        scheduledBufferCount.value = 0
        playbackStartPosition = 0
        
        // Prepare the audio engine for playback, telling it which audio format it needs to play.
        audioEngine.prepareForFile(with: fileContext.audioFormat)
        
        // Initiate scheduling of audio buffers on the audio engine's playback queue.
        initiateDecodingAndScheduling()
        
        // Check that at least one audio buffer was successfully scheduled, before beginning playback.
        if scheduledBufferCount.value > 0 {
            beginPlayback()
        }
    }
    
    ///
    /// Seeks to a given position within the currently playing file.
    ///
    /// - Parameter time: The desired seek position, specified in seconds. Must be greater than 0.
    ///
    /// # Notes #
    ///
    /// 1. If the seek takes the player past the end of the currently playing file, i.e. EOF,
    /// an NSNotification named **player_playbackCompleted** will be published, and playback will come to a stop.
    ///
    /// 2. When EOF has not been reached, the player's playback state will be the same as it was
    /// before the requested seek, i.e. either **paused** or **playing**.
    ///
    /// 3. Does nothing if no file is currently playing.
    ///
    func seek(to time: Double) {
        
        guard playingFile != nil else {return}
        
        let wasPlaying: Bool = audioEngine.isPlaying
        
        haltPlayback()
        initiateDecodingAndScheduling(from: time)
        
        if scheduledBufferCount.value > 0 {
            
            if wasPlaying {
                beginPlayback(from: time)
                
            } else {
                playbackStartPosition = time
            }
        }
    }
    
    ///
    /// Toggles the player between the **playing / paused** playback states.
    ///
    /// # Notes #
    ///
    /// Does nothing if no file is currently playing.
    ///
    func togglePlayPause() {
        
        if playingFile != nil {
            
            audioEngine.pauseOrResume()
            state = audioEngine.isPlaying ? .playing : .paused
        }
    }
    
    ///
    /// Stops playback of the currently playing file, and performs all appropriate cleanup (deallocation of memory, etc).
    ///
    /// # Notes #
    ///
    /// Does nothing if no file is currently playing.
    ///
    func stop() {
        
        if playingFile != nil {
            playbackCompleted()
        }
    }
    
    ///
    /// Stops playback of the currently playing file.
    ///
    /// # Notes #
    ///
    /// Does nothing if no file is currently playing.
    ///
    private func haltPlayback() {
        
        state = .stopped
        
        stopScheduling()
        audioEngine.stop()
        decoder?.stop()
    }
    
    ///
    /// Initiates playback of the audio engine.
    ///
    /// - Parameter seekPosition:   The seek position, specified in seconds, from which playback is
    ///                             beginning.
    ///
    /// # Notes #
    ///
    /// Does nothing if no file is currently playing.
    ///
    func beginPlayback(from seekPosition: Double = 0) {

        playbackStartPosition = seekPosition
        
        audioEngine.play()
        state = .playing
    }
    
    ///
    /// Performs cleanup and (optionally) notifies observers when playback of the currently playing file has completed.
    ///
    /// - Parameter notifyObservers: When true, an NSNotification will be published. True is the default value.
    ///
    /// # Notes #
    ///
    /// The function may also be used for cleanup without notifying observers. e.g. before starting playback of a file.
    ///
    func playbackCompleted(_ notifyObservers: Bool = true) {

        haltPlayback()
        decoder?.stop()
        
        playingFile = nil

        if notifyObservers {
            NotificationCenter.default.post(name: .player_playbackCompleted, object: self)
        }
    }
}

///
/// Enumerates all possible playback states the player can be in.
///
enum PlayerState {
    
    /// Not playing any track
    case stopped
    
    /// Playing a track
    case playing
    
    /// Paused while playing a track
    case paused
}

///
/// Names for custom notifications published by the player
///
extension Notification.Name {
    
    static let player_playbackCompleted = NSNotification.Name("player_playbackCompleted")
}
