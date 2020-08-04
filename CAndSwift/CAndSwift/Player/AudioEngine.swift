import AVFoundation

///
/// Helper class that encapsulates an AVAudioEngine audio graph that sends audio to the output hardware..
///
/// - Manages connections between audio graph nodes.
/// - Directly controls playback state (playing / paused / stopped) and volume through an AVAudioPlayerNode.
/// - Performs upmixing/downmixing from mono/surround to stereo audio.
/// - Provides the player's seek position within a track.
///
class AudioEngine {

    let audioEngine: AVAudioEngine
    let playerNode: AVAudioPlayerNode
    let auxMixer: AVAudioMixerNode

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        auxMixer = AVAudioMixerNode()

        playerNode.volume = 1
        auxMixer.volume = 1

        audioEngine.attach(playerNode)
        audioEngine.attach(auxMixer)

        audioEngine.connect(playerNode, to: auxMixer, format: nil)
        audioEngine.connect(auxMixer, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()

        do {
            try audioEngine.start()
            
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    func prepare(_ format: AVAudioFormat) {

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: auxMixer, format: format)
    }

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: AVAudioNodeCompletionHandler? = nil) {
        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler)
    }

    func play() {
        playerNode.play()
    }
    
    func pauseOrResume() {
        playerNode.isPlaying ? pause() : play()
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func stop() {
        playerNode.stop()
    }
    
    var volume: Float {
        
        get {playerNode.volume}
        set {playerNode.volume = min(1, max(0, newValue))}
    }
    
    var hasBeenStopped: Bool = false
    var isPlaying: Bool {playerNode.isPlaying}

    // TODO: Remove startFrame from here. Let Player remember "startTime" (in seconds)
    var startFrame: AVAudioFramePosition = 0
    var cachedSeekPosn: Double = 0
    
    func seekTo(_ seconds: Double) {
        
        let format = playerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        
        startFrame = Int64(sampleRate * seconds)
        cachedSeekPosn = seconds
    }
    
    func playbackCompleted() {
        
        startFrame = 0
        cachedSeekPosn = 0
    }
    
    // TODO: This should only compute position in frames. Let Player convert it to seconds and add start time.
    var seekPosition: Double {
        
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            cachedSeekPosn = Double(startFrame + playerTime.sampleTime) / playerTime.sampleRate
        }
        
        // Default to last remembered position when nodeTime is nil
        return cachedSeekPosn
    }
    
    deinit {
        
        // Release the audio engine resources
        audioEngine.stop()
    }
}
