import Foundation

class BufferedFrame: Hashable {
    
    var rawDataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
    private var actualDataPointers: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>
    private var allocatedDataPointerCount: Int
    
    let channelLayout: UInt64
    let channelCount: Int
    let sampleCount: Int32
    let sampleRate: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    let timestamp: Int64
    
    init(_ frame: Frame) {
        
        self.timestamp = frame.timestamp

        self.channelLayout = frame.channelLayout
        self.channelCount = Int(frame.channelCount)
        self.sampleCount = frame.sampleCount
        self.sampleRate = frame.sampleRate
        self.lineSize = frame.lineSize
        self.sampleFormat = frame.sampleFormat
        
        let sourceBuffers = frame.dataPointers
        self.actualDataPointers = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: channelCount)
        self.allocatedDataPointerCount = 0
        
        for channelIndex in (0..<8) {
            
            guard let sourceBuffer = sourceBuffers[channelIndex] else {break}
            
            actualDataPointers[channelIndex] = UnsafeMutablePointer<UInt8>.allocate(capacity: lineSize)
            actualDataPointers[channelIndex]?.initialize(from: sourceBuffer, count: lineSize)
            
            allocatedDataPointerCount += 1
        }
        
        self.rawDataPointers = UnsafeMutableBufferPointer(start: actualDataPointers, count: channelCount)
    }
    
    var playableFloatPointers: [UnsafePointer<Float>] {
        
        guard let ptr: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?> = rawDataPointers.baseAddress else {return []}
        
        var floats: [UnsafePointer<Float>] = []
        let intSampleCount: Int = Int(sampleCount)
        
        for channelIndex in 0..<channelCount {
            
            guard let bytesForChannel = ptr[channelIndex] else {break}
            
            floats.append(bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount)
            {(pointer: UnsafeMutablePointer<Float>) in UnsafePointer(pointer)})
        }
        
        return floats
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        
        for index in 0..<allocatedDataPointerCount {
            self.actualDataPointers[index]?.deallocate()
        }
        
        self.actualDataPointers.deallocate()
        
        destroyed = true
    }
    
    deinit {
        destroy()
    }
    
    static func == (lhs: BufferedFrame, rhs: BufferedFrame) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
    }
}
