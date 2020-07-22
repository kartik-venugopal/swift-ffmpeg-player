import AVFoundation
import ffmpeg

class AudioEngine {

    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode
    internal let timeNode: AVAudioUnitVarispeed

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        timeNode = AVAudioUnitVarispeed()
        timeNode.rate = 1
        
        playerNode.volume = 1

        audioEngine.attach(playerNode)
        audioEngine.attach(timeNode)
        
        audioEngine.connect(playerNode, to: timeNode, format: nil)
        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    func prepare(_ format: AVAudioFormat) {

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(timeNode)

        audioEngine.connect(playerNode, to: timeNode, format: format)
        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: format)
    }

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, _ completionHandler: AVAudioNodeCompletionHandler? = nil) {

        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler ?? {
            print("\nDONE playing buffer:", buffer.frameLength, buffer.frameCapacity)
        })
    }

    func play() {
        playerNode.play()
    }
}
