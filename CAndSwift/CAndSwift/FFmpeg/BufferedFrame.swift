import Foundation

class BufferedFrame: Hashable {
    
    var dataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
    
    let channelLayout: UInt64
    let channelCount: Int
    let sampleCount: Int32
    let sampleRate: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    let timestamp: Int64
    
    // channelLayout comes from the Codec (cannot rely on avFrame.channel_layout).
    init(_ frame: Frame) {
        
        self.timestamp = frame.timestamp

        self.channelLayout = frame.channelLayout
        self.channelCount = Int(frame.channelCount)
        self.sampleCount = frame.sampleCount
        self.sampleRate = frame.sampleRate
        self.lineSize = frame.lineSize
        self.sampleFormat = frame.sampleFormat
        
        let sourceBuffers = frame.dataPointers
        let destinationBuffers = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: channelCount)
        
        for channelIndex in (0..<8) {
            
            guard let sourceBuffer = sourceBuffers[channelIndex] else {break}
            destinationBuffers[channelIndex] = UnsafeMutablePointer<UInt8>.allocate(capacity: lineSize)
            destinationBuffers[channelIndex]?.initialize(from: sourceBuffer, count: lineSize)
        }
        
        self.dataPointers = UnsafeMutableBufferPointer(start: destinationBuffers, count: channelCount)
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
