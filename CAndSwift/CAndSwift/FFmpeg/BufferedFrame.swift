import Foundation

class BufferedFrame: Hashable {
    
    var dataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
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
        
        self.dataPointers = UnsafeMutableBufferPointer(start: actualDataPointers, count: channelCount)
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

extension AVFrame {
    
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8))
    }
}
