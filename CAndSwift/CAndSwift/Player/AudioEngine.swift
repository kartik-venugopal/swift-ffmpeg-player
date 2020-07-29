import AVFoundation
//import ffmpeg

class AudioEngine {

    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        playerNode.volume = 1

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    func prepare(_ format: AVAudioFormat) {

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
    }

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, _ completionHandler: AVAudioNodeCompletionHandler? = nil) {

        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler ?? {
            print("\nDone playing buffer:", buffer.frameLength)
        })
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
        
        hasBeenStopped = true
        playerNode.stop()
        hasBeenStopped = false
    }
    
    var volume: Float {
        
        get {playerNode.volume}
        set {playerNode.volume = min(1, max(0, newValue))}
    }
    
    var hasBeenStopped: Bool = false
    var isPlaying: Bool {playerNode.isPlaying}

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
    
    var seekPosition: Double {
        
        print("\nIsPlaying ? \(playerNode.isPlaying)")
        
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            cachedSeekPosn = Double(startFrame + playerTime.sampleTime) / playerTime.sampleRate
        }

        // Default to last remembered position when nodeTime is nil
        return cachedSeekPosn
    }
}
