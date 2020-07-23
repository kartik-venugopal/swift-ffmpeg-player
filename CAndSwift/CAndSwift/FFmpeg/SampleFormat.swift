import Foundation

struct SampleFormat {
    
    let avFormat: AVSampleFormat
    
    let name: String
    let size: Int
    let isPlanar: Bool
    
    init(avFormat: AVSampleFormat) {
        
        self.avFormat = avFormat
        self.name = String(cString: av_get_sample_fmt_name(avFormat))
        self.size = Int(av_get_bytes_per_sample(avFormat))
        self.isPlanar = av_sample_fmt_is_planar(avFormat) == 1
    }
}
