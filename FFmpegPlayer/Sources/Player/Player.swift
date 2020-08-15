import AVFoundation

///
/// Facade for all high-level playback functions - play / pause / stop / seeking / volume control.
/// Suitable for direct use by a user interface.
///
class Player {
    
    /// A helper object that does the actual decoding.
    let decoder: Decoder = Decoder()
    
    let sampleConverter: SampleConverter = SampleConverter()
    
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
    
    ///
    /// The codec for the currently playing file.
    /// May be nil (if no file is currently playing).
    ///
    var codec: AudioCodec! {playingFile.audioCodec}
    
    ///
    /// The audio format for the currently playing file.
    /// May be nil (if no file is currently playing).
    ///
    /// # Note #
    ///
    /// All audio buffers will be set to this format when scheduled for playback.
    ///
    var audioFormat: AVAudioFormat!
    
    ///
    /// The maximum number of samples that will be read, decoded, and scheduled for **immediate** playback,
    /// i.e. when **play(file)** is called, triggered by the user.
    ///
    /// # Notes #
    ///
    /// 1. This value should be small enough so that, when starting playback
    /// of a file, there is little to no perceived lag. Typically, this should represent about 2-5 seconds of audio (depending on sample rate).
    ///
    /// 2. This value should generally be smaller than *sampleCountForDeferredPlayback*.
    ///
    var sampleCountForImmediatePlayback: Int32 = 0
    
    ///
    /// The maximum number of samples that will be read, decoded, and scheduled for **deferred** playback, i.e. playback that will occur
    /// at a later time, as the result, of a recursive scheduling task automatically triggered when a previously scheduled audio buffer has finished playing.
    ///
    /// # Notes #
    ///
    /// 1. The greater this value, the longer each recursive scheduling task will take to complete, and the larger the memory footprint of each audio buffer.
    /// The smaller this value, the more often disk reads will occur. Choose a value that is a good balance between memory usage, decoding / resampling time, and frequency of disk reads.
    /// Example: 10-20 seconds of audio (depending on sample rate).
    ///
    /// 2. This value should generally be larger than *sampleCountForImmediatePlayback*.
    ///
    var sampleCountForDeferredPlayback: Int32 = 0
    
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
        
        return playbackStartPosition + (Double(audioEngine.framePosition) / audioFormat.sampleRate)
    }

    ///
    /// Prepares the player to play a given audio file.
    ///
    /// ```
    /// This function will be called exactly once when a file is chosen for immediate playback.
    /// ```
    ///
    /// - Parameter file: A context through which decoding of the audio file can be performed.
    ///
    /// - throws: A **DecoderInitializationError** if the decoder cannot be initialized.
    ///
    private func initialize(with file: AudioFileContext) throws {
        
        self.playingFile = file
        
        // Try to open the codec.
        try decoder.initialize(with: file)
        
        let codec: AudioCodec = playingFile.audioCodec
        
        let sampleRate: Int32 = codec.sampleRate
        let channelCount: Int32 = codec.channelCount
        
        // The effective sample rate, which also takes into account the channel count, gives us a better idea
        // of the computational cost of decoding and resampling the given file, as opposed to just the
        // sample rate.
        let effectiveSampleRate: Int32 = sampleRate * channelCount
        
        guard let channelLayout = ChannelLayouts.mapLayout(ffmpegLayout: Int(codec.channelLayout)) else {
            
            print("\nFailed to initialize Player: Invalid ffmpeg channel layout: \(codec.channelLayout)")
            throw PlayerInitializationError()
        }

        // Determine the audio format for all audio buffers that will be scheduled for playback.
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channelLayout: channelLayout)
        
        // Inform the audio engine that the audio buffers for this file will be of this format, so that
        // it can prepare itself accordingly.
        audioEngine.prepareForFile(with: audioFormat)
        
        // Given the effective sample rate, determine how many samples we should schedule for immediate and deferred playback.
        
        switch effectiveSampleRate {
            
        case 0..<100000:
            
            // 44.1 / 48 KHz stereo
            
            sampleCountForImmediatePlayback = 5 * sampleRate    // 5 seconds of audio
            sampleCountForDeferredPlayback = 10 * sampleRate    // 10 seconds of audio
            
        case 100000..<500000:
            
            // 96 / 192 KHz stereo
            
            sampleCountForImmediatePlayback = 3 * sampleRate    // 3 seconds of audio
            sampleCountForDeferredPlayback = 10 * sampleRate    // 10 seconds of audio
            
        default:
            
            // 96 KHz surround and higher sample rates
            
            sampleCountForImmediatePlayback = 2 * sampleRate    // 2 seconds of audio
            sampleCountForDeferredPlayback = 7 * sampleRate     // 7 seconds of audio
        }
        
        scheduledBufferCount.value = 0
        playbackStartPosition = 0
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
        
        let time = measureExecutionTime {
            
        // Reset player and decoder state before playback.
        playbackCompleted(false)
    
        do {
        
            // Prepare decoder and audio engine.
            try initialize(with: fileContext)
            
            // Initiate scheduling of audio buffers on the audio engine's playback queue.
            initiateDecodingAndScheduling()
            
            // Check that at least one audio buffer was successfully scheduled, before beginning playback.
            if scheduledBufferCount.value > 0 {
                beginPlayback()
            }
            
        } catch {
            print("Player setup for file '\(fileContext.file.path)' failed !")
        }
            
        }
        
        print("\nPlayer took \(time * 1000) msec to initiate playback.")
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
        decoder.stop()
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
        decoder.playbackCompleted()
        
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
