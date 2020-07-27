import Foundation

class Frame: Hashable {
    
    var dataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
    
    let channelLayout: UInt64
    let channelCount: Int
    let sampleCount: Int32
    let sampleRate: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    let timestamp: Int64
    
    init(_ frame: UnsafeMutablePointer<AVFrame>, sampleFormat: SampleFormat) {
        
        self.timestamp = frame.pointee.best_effort_timestamp

        self.channelLayout = frame.pointee.channel_layout
        self.channelCount = Int(frame.pointee.channels)
        self.sampleCount = frame.pointee.nb_samples
        self.sampleRate = frame.pointee.sample_rate
        self.lineSize = Int(frame.pointee.linesize.0)
        
        self.sampleFormat = sampleFormat
        
        let inData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 4)
        inData.initialize(to: nil)
        av_samples_alloc(inData, nil, Int32(channelCount), sampleCount, sampleFormat.avFormat, 0)
        self.dataPointers = UnsafeMutableBufferPointer(start: inData, count: 4)
        
        let bufferPointers = frame.pointee.dataPointers
        
        for channelIndex in (0..<8) {
            
            guard let buffer = bufferPointers[channelIndex] else {break}
            memcpy(inData[channelIndex], buffer, lineSize)
        }
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
