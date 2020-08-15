import AVFoundation

extension AVAudioFormat {
    
    convenience init?(from sampleFormat: SampleFormat, sampleRate: Int32, channelLayoutId: Int64) {
        
        guard let channelLayout = ChannelLayouts.mapLayout(ffmpegLayout: Int(channelLayoutId)) else {
            return nil
        }
        
        var commonFmt: AVAudioCommonFormat
        
        switch sampleFormat.avFormat {
            
        case AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P:
            
            commonFmt = .pcmFormatInt16
            
        case AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P:
            
            commonFmt = .pcmFormatInt32
            
        case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
            
            commonFmt = .pcmFormatFloat32
            
        default:
            
            return nil
        }
        
        self.init(commonFormat: commonFmt, sampleRate: Double(sampleRate), interleaved: sampleFormat.isInterleaved, channelLayout: channelLayout)
    }
}
