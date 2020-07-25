import AVFoundation
import Accelerate
//import ffmpeg

class SamplesBuffer {
    
    var frames: [Frame] = []
    
    let sampleFormat: SampleFormat
    
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(sampleFormat: SampleFormat, maxSampleCount: Int32) {
        
        self.sampleFormat = sampleFormat
        self.maxSampleCount = maxSampleCount
    }
    
    func appendFrame(frame: Frame) {
        
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    var opq: OperationQueue = {
        
        let opq = OperationQueue()
        
        opq.qualityOfService = .userInteractive
        opq.underlyingQueue = .global(qos: .userInteractive)
        opq.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount / 2
        
        return opq
    }()
    
    let planarDataMap: ConcurrentMap<Int, [[Float]]> = ConcurrentMap<Int, [[Float]]>("planar-unpacking")
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        
        if !sampleFormat.isPlanar {
            return constructAudioBuffer_packed(format: format)
        }

        guard sampleCount > 0 else {return nil}
        
        // Planar samples
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let time = measureTime {
                
                buffer.frameLength = buffer.frameCapacity
                let channels = buffer.floatChannelData
                
                var allFrames: [[[Float]]] = []
                planarDataMap.removeAll()
                
                opq.addOperations((0..<frames.count).map {index in
                    
                    BlockOperation {
                        self.planarDataMap[index] = self.frames[index].planarFloatData
                    }
                    
                }, waitUntilFinished: true)
                
                allFrames = planarDataMap.kvPairs.sorted(by: {$0.0 < $1.0}).map {$0.value}
                
                var sampleCountSoFar: Int = 0
                
                for index in 0..<frames.count {
                    
                    let frame = frames[index]
                    let frameFloats: [[Float]] = allFrames[index]
                    
                    for channelIndex in 0..<min(2, frameFloats.count) {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        let frameFloatsForChannel: [Float] = frameFloats[channelIndex]
                        
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                    }
                    
                    sampleCountSoFar += Int(frame.sampleCount)
                }
                
            }
            
            print("\nConstruct PLANAR: \(time * 1000) msec")
            
            return buffer
        }
        
        return nil
    }
    
    let packedDataMap: ConcurrentMap<Int, [Float]> = ConcurrentMap<Int, [Float]>("unpacking")
    
    func constructAudioBuffer_packed(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        
        guard sampleCount > 0 else {return nil}
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let time = measureTime {
                
                buffer.frameLength = buffer.frameCapacity
                let channels = buffer.floatChannelData
                
                var allFrames: [[Float]] = []
                packedDataMap.removeAll()
                
                opq.addOperations((0..<frames.count).map {index in
                    
                    BlockOperation {
                        self.packedDataMap[index] = self.frames[index].packedFloatData
                    }
                    
                }, waitUntilFinished: true)
                
                allFrames = packedDataMap.kvPairs.sorted(by: {$0.0 < $1.0}).map {$0.value}
                
                let numChannels = Int(format.channelCount)
                var sampleCountSoFar: Int = 0
                
                
                for index in 0..<frames.count {
                    
                    let frame = frames[index]
                    let packedFloats: [Float] = allFrames[index]
                    
                    for channelIndex in 0..<numChannels {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        cblas_scopy(Int32(packedFloats.count / numChannels), channelIndex == 0 ? packedFloats : Array(packedFloats.suffix(from: channelIndex)),
                                    Int32(numChannels), channel.advanced(by: sampleCountSoFar), 1)
                    }
                    
                    sampleCountSoFar += Int(frame.sampleCount)
                }
                
            }
            
            print("\nConstruct: \(time * 1000) msec")
            
            return buffer
        }
        
        return nil
    }
}
