import Foundation

struct SampleFormat {
    
    let avFormat: AVSampleFormat
    
    let name: String
    let size: Int
    
    let isPlanar: Bool
    var isInterleaved: Bool {!isPlanar}
    
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
}
