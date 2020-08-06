import AVFoundation

///
/// Helper class that encapsulates an AVAudioEngine audio graph that sends audio to the output hardware.
///
/// - Manages the audio engine life cycle.
/// - Manages connections (and their audio formats) between audio graph nodes.
/// - Accepts audio buffers into the playback queue
/// - Directly controls playback state (playing / paused / stopped) and volume.
/// - Performs upmixing / downmixing from mono/surround to stereo audio.
/// - Performs upsampling / downsampling between different sample rates.
/// - Provides the player's seek position within a track.
///
/// ```
/// The audio graph in this class can be pictured as a sequential signal processing chain.
///
/// playerNode -> auxMixer -> mainMixer -> outputNode
///
/// As audio travels from one node to the next, each node may "process" the audio in some way.
///
/// Finally, the audio engine's output node passes the audio to the hardware device.
/// ```
///
class AudioEngine {

    /// The parent object in the audio graph.
    private let audioEngine: AVAudioEngine
    
    ///
    /// The node responsible for:
    ///
    /// - Scheduling and playback of audio buffers
    /// - Control of playback state (playing / paused / stopped)
    /// - Volume control
    ///
    /// ```
    /// This node maintains an internal playback queue where
    /// any scheduled audio buffers are enqueued.
    ///
    /// When one buffer finishes playing, its completion handler
    /// is invoked, and the next buffer in the queue is picked up
    /// and starts playing seamlessly.
    ///
    /// When **stop()** is called on this node, its playback
    /// queue is flushed, and the completion handlers of all
    /// scheduled audio buffers are executed.
    /// ```
    ///
    ///
    private let playerNode: AVAudioPlayerNode
    
    ///
    /// The node responsible for:
    ///
    /// - Upmixing / downmixing:                    Converting from the channel layout (mono / stereo / surround) of the audio file to that of the output hardware.
    /// - Upsampling / downsampling:            Converting from the sample rate of the audio file to that of the output hardware.
    ///
    ///  # Notes #
    ///
    ///  No special configuration is necessary for the **auxMixer** to do its job.
    ///  We simply connect **playerNode** to it with the audio format (i.e. channel layout and sample rate) of the input audio file,
    ///  and the **auxMixer** will automatically do any necessary upmixing / downmixing and/or upsampling / downsampling.
    ///
    ///
    private let auxMixer: AVAudioMixerNode
    
    ///
    /// Volume of the player node.
    ///
    var volume: Float {
        
        get {playerNode.volume}
        
        // Clamp the new value to ensure that it is in the valid range: 0...1
        set {playerNode.volume = min(1, max(0, newValue))}
    }
    
    ///
    /// Whether or not the player node is currently playing.
    ///
    var isPlaying: Bool {playerNode.isPlaying}

    ///
    /// Cached seek position of the player node, in frames.
    ///
    /// Used to remember the last computed seek position and avoid displaying 0 when the player is temporarily paused / stopped.
    ///
    var cachedSeekPosn: AVAudioFramePosition = 0
    
    ///
    /// The current seek position of the player node, in frames.
    ///
    /// It is computed as a function of the player node's "sample time" (number of samples played)
    /// and the sample rate of the audio buffer that is being played.
    ///
    /// # Notes #
    ///
    /// When the player is either paused or stopped, the last remembered frame position will be returned.
    ///
    var framePosition: AVAudioFramePosition {
        
        // nodeTime will be nil when the player node is paused or stopped.
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            cachedSeekPosn = playerTime.sampleTime
        }
        
        return cachedSeekPosn
    }

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        auxMixer = AVAudioMixerNode()

        playerNode.volume = 1
        auxMixer.volume = 1

        // Set up the audio graph's connections.
        
        audioEngine.attach(playerNode)
        audioEngine.attach(auxMixer)

        audioEngine.connect(playerNode, to: auxMixer, format: nil)
        audioEngine.connect(auxMixer, to: audioEngine.mainMixerNode, format: nil)
        
        // Prepare the audio engine to process/render audio.

        audioEngine.prepare()

        do {
            try audioEngine.start()
            
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    ///
    /// Prepares the audio engine to play audio in a given format.
    ///
    /// - Parameter format: The audio format of the file that is about to be played.
    ///                     Specifies the channel layout and sample rate of any samples
    ///                     obtained from the file.
    ///
    /// This function should be called exactly once prior to starting playback of a file.
    ///
    func prepareForFile(with format: AVAudioFormat) {

        // Re-connect the player node to the auxiliary mixer node,
        // with the new file's audio format.
        
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: auxMixer, format: format)
    }

    ///
    /// Enqueues an audio buffer on the player node's internal playback queue.
    ///
    /// - Parameter buffer:                 An audio buffer containing 32-bit floating point non-interleaved (i.e. planar) PCM samples.
    ///
    /// - Parameter completionHandler:      Code to execute when the buffer finishes playing. May be nil.
    ///
    /// ```
    /// Typically, the completion handler is used to recursively schedule more audio buffers, or when
    /// the end of the file is reached, to signal completion of playback of the file.
    /// ```
    ///
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: AVAudioNodeCompletionHandler? = nil) {
        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler)
    }

    ///
    /// Commands the player node to begin playback.
    ///
    func play() {
        playerNode.play()
    }
    
    ///
    /// Toggles the playback state of the player node between paused and playing.
    ///
    func pauseOrResume() {
        playerNode.isPlaying ? pause() : play()
    }
    
    ///
    /// Commands the player node to pause playback.
    ///
    func pause() {
        playerNode.pause()
    }
    
    ///
    /// Commands the player node to stop playback.
    ///
    /// # Notes #
    ///
    /// ```
    /// Stopping the player node has 2 important side effects:
    ///
    /// 1 - The completion handlers of all scheduled buffers are executed, even if they have not finished playing.
    ///
    /// 2 - The player node's "sample time" (used to compute the current seek position) is reset to 0.
    /// ```
    ///
    func stop() {
        
        playerNode.stop()
        cachedSeekPosn = 0
    }
    
    ///
    /// Performs cleanup prior to object deinitialization.
    ///
    deinit {
        
        // Release the audio engine's resources
        audioEngine.stop()
    }
}
