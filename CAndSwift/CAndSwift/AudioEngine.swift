import AVFoundation
import ffmpeg

class AudioEngine {

    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode
//    internal let timeNode: AVAudioUnitVarispeed

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
//        timeNode = AVAudioUnitVarispeed()
//        timeNode.rate = 1
        
        playerNode.volume = 1

        audioEngine.attach(playerNode)
//        audioEngine.attach(timeNode)
        
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
//        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    func prepare(_ format: AVAudioFormat) {

        audioEngine.disconnectNodeOutput(playerNode)
//        audioEngine.disconnectNodeOutput(timeNode)

        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
//        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: format)
    }

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, _ completionHandler: AVAudioNodeCompletionHandler? = nil) {

        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler ?? {
            print("\nDONE playing buffer:", buffer.frameLength, buffer.frameCapacity)
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
        
        if playerNode.isPlaying {
            playerNode.stop()
        }
    }
    
    var volume: Float {
        
        get {playerNode.volume}
        set {playerNode.volume = min(1, max(0, newValue))}
    }
    
    var isPlaying: Bool {playerNode.isPlaying}

    var startFrame: AVAudioFramePosition = 0
    var cachedSeekPosn: Double = 0
    
    func seekTo(_ seconds: Double) {
        
        let format = playerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        
        startFrame = Int64(sampleRate * seconds)
    }
    
    func playbackCompleted() {
        
        startFrame = 0
        cachedSeekPosn = 0
    }
    
    var seekPosition: Double {
        
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            cachedSeekPosn = Double(startFrame + playerTime.sampleTime) / playerTime.sampleRate
        }

        // Default to last remembered position when nodeTime is nil
        return cachedSeekPosn
    }
}
