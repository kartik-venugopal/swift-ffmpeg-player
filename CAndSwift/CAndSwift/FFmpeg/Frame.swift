import Foundation

class Frame {
 
    var avFrame: AVFrame
    
    var channelLayout: UInt64 {avFrame.channel_layout}
    var channelCount: Int32 {avFrame.channels}

    var sampleFormat: SampleFormat
    var sampleCount: Int32 {avFrame.nb_samples}
    var hasSamples: Bool {avFrame.nb_samples.isPositive}
    var sampleRate: Int32 {avFrame.sample_rate}
    
    var lineSize: Int {Int(avFrame.linesize.0)}
    
    var timestamp: Int64 {avFrame.best_effort_timestamp}
    
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {avFrame.dataPointers}
    
    init(sampleFormat: SampleFormat) {
        
        self.avFrame = AVFrame()
        self.sampleFormat = sampleFormat
    }
    
    func receiveFrom(_ codec: Codec) -> ResultCode {
        return avcodec_receive_frame(codec.contextPointer, &avFrame)
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        av_frame_unref(&avFrame)
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}

extension AVFrame {
    
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8))
    }
}
