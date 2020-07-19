import AVFoundation
import ffmpeg

class Player {
    
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

class AudioData {
    
    var datas: [Data] = []
    var lineSizes: [Int] = []

    var numFrames: Int = 0
    var numSamples: Int = 0
    var sampleRate: Int = 0
    
    // Hold up to 5 seconds of samples in one object
    var isFull: Bool {self.numFrames > 0 && self.numSamples >= 5 * sampleRate}
    
    func reset(_ sampleRate: Int) {
        
        self.sampleRate = sampleRate
        self.numSamples = 0
        self.numFrames = 0
        
        self.datas.removeAll()
        self.lineSizes.removeAll()
    }
    
    func appendFrame(_ frame: UnsafeMutablePointer<AVFrame>) {
        
        self.numSamples += Int(frame.pointee.nb_samples)
        let buffers = frame.pointee.datas()
        
        let lineSize = Int(frame.pointee.linesize.0)
        let noFramesYet = numFrames == 0
        
        for (index, buffer) in (0..<8).compactMap({buffers[$0]}).enumerated() {
            
            if noFramesYet {
                
                datas.append(Data(bytes: buffer, count: lineSize))
                lineSizes.append(lineSize)
            
            } else {
                
                datas[index].append(contentsOf: Data(bytes: buffer, count: lineSize))
                lineSizes[index] += lineSize
            }
        }
        
        numFrames += 1
        
        print("\nNOW BUFFERED-AUDIO-DATA:", numSamples, sampleRate, lineSizes, datas[0].count, isFull)
    }
}

extension AVFrame {
    
    mutating func datas() -> [UnsafeMutablePointer<UInt8>?] {
        
        let ptr = UnsafeBufferPointer(start: self.extended_data, count: 8)
        let arr = Array(ptr)
        return arr
    }
}
