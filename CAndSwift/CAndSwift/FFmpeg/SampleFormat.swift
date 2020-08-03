import Foundation

///
/// Wrapper around an AVSampleFormat struct.
///
/// Reads and provides useful information about the format of audio samples,
/// e.g. whether or not samples of this format need to be resampled for playback.
///
struct SampleFormat {
    
    let avFormat: AVSampleFormat
    
    let name: String
    let size: Int
    
    let isPlanar: Bool
    var isInterleaved: Bool {!isPlanar}
    
    var isIntegral: Bool {
        
        [AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P,
         AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P, AV_SAMPLE_FMT_S64, AV_SAMPLE_FMT_S64P].contains(avFormat)
    }
    
    var needsResampling: Bool {
        avFormat != AV_SAMPLE_FMT_FLTP
    }
    
    init(avFormat: AVSampleFormat) {
        
        self.avFormat = avFormat
        
        if let fmtNamePointer = av_get_sample_fmt_name(avFormat) {
            self.name = String(cString: fmtNamePointer)
        } else {
            self.name = "<Unknown sample format>"
        }
        
        self.size = Int(av_get_bytes_per_sample(avFormat))
        self.isPlanar = av_sample_fmt_is_planar(avFormat) == 1
    }
    
    var description: String {
        
        switch avFormat {
            
        case AV_SAMPLE_FMT_U8:       return "Unsigned 8-bit integer (Interleaved)"
            
        case AV_SAMPLE_FMT_S16:      return "Signed 16-bit integer (Interleaved)"
            
        case AV_SAMPLE_FMT_S32:      return "Signed 32-bit integer (Interleaved)"
            
        case AV_SAMPLE_FMT_S64:      return "Signed 64-bit integer (Interleaved)"
            
        case AV_SAMPLE_FMT_FLT:      return "Floating-point (Interleaved)"
            
        case AV_SAMPLE_FMT_DBL:      return "Double precision floating-point (Interleaved)"
            
        case AV_SAMPLE_FMT_U8P:       return "Unsigned 8-bit integer (Planar)"
            
        case AV_SAMPLE_FMT_S16P:      return "Signed 16-bit integer (Planar)"
            
        case AV_SAMPLE_FMT_S32P:      return "Signed 32-bit integer (Planar)"
            
        case AV_SAMPLE_FMT_S64P:      return "Signed 64-bit integer (Planar)"
            
        case AV_SAMPLE_FMT_FLTP:      return "Floating-point (Planar)"
                
        case AV_SAMPLE_FMT_DBLP:      return "Double precision floating-point (Planar)"
            
        default:                      return "<Unknown Sample Format>"
            
        }
    }
}
