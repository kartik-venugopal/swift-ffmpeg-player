import Foundation

class Frame: Hashable {
    
    static var ctr: Int = 0
    
    var dataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
    
    let channelLayout: UInt64
    let channelCount: Int
    let sampleCount: Int32
    let sampleRate: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    let timestamp: Int64
    
    // channelLayout comes from the Codec (cannot rely on avFrame.channel_layout).
    init(_ frame: UnsafeMutablePointer<AVFrame>, sampleFormat: SampleFormat, channelLayout: UInt64) {
        
        Self.ctr += 1
        print("\nCreating frame# \(Self.ctr) \(frame.pointee.nb_samples) \(frame.pointee.format)")
        
        self.timestamp = frame.pointee.best_effort_timestamp

        self.channelLayout = channelLayout
        self.channelCount = Int(frame.pointee.channels)
        self.sampleCount = frame.pointee.nb_samples
        self.sampleRate = frame.pointee.sample_rate
        self.lineSize = Int(frame.pointee.linesize.0)
        
        self.sampleFormat = sampleFormat
        
        let bufferPointers = frame.pointee.dataPointers
        let ptrs = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: channelCount)
        
        for channelIndex in (0..<8) {
            
            guard let buffer = bufferPointers[channelIndex] else {break}
            ptrs[channelIndex] = UnsafeMutablePointer<UInt8>.allocate(capacity: lineSize)
            ptrs[channelIndex]?.initialize(from: buffer, count: lineSize)
        }
        
        self.dataPointers = UnsafeMutableBufferPointer(start: ptrs, count: channelCount)
    }
    
    static func == (lhs: Frame, rhs: Frame) -> Bool {
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
