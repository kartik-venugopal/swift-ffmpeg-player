import AVFoundation

///
/// Constants used application-wide
///
struct Constants {
    
    static let audioFileExtensions: [String] = ["aac", "adts", "ac3", "aif", "aiff", "aifc", "caf", "flac", "mp3", "m4a", "m4b", "m4r", "snd", "au", "sd2", "wav", "oga", "ogg", "opus", "wma", "dsf", "mpc", "mp2", "ape", "wv", "dts", "mka"]
    
    static let rawAudioFileExtensions: [String] = ["aac", "adts", "ac3", "dts"]
    
    static let avFileTypes: [String] = [AVFileType.mp3.rawValue, AVFileType.m4a.rawValue, AVFileType.aiff.rawValue, AVFileType.aifc.rawValue, AVFileType.caf.rawValue, AVFileType.wav.rawValue, AVFileType.ac3.rawValue]
}
