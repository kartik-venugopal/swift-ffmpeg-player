import AVFoundation

///
/// Constants used application-wide.
///
struct Constants {
    
    ///
    /// A comprehensive list of all allowed audio file extensions,
    /// i.e. all file types that can be played by our player.
    ///
    static let audioFileExtensions: [String] = ["8svx", "aac", "adts", "ac3", "aif", "aiff", "aifc", "caf", "flac", "mp3", "m4a", "m4b", "m4r", "snd", "au", "sd2", "wav", "oga", "ogg", "opus", "wma", "dsf", "mpc", "mp2", "ape", "wv", "dts", "mka", "paf", "tta", "ra", "ram", "rm", "tak", "aa", "mlp", "nut"]
    
    ///
    /// A list of extensions of files that represent raw audio streams that lack accurate duration information.
    ///
    static let rawAudioFileExtensions: [String] = ["aac", "adts", "ac3", "dts"]
    
    ///
    /// A list of AVFoundation file type UTIs.
    /// These are needed in order to properly display certain file types in file open dialogs.
    ///
    static let avFileTypes: [String] = [AVFileType.mp3.rawValue, AVFileType.m4a.rawValue, AVFileType.aiff.rawValue, AVFileType.aifc.rawValue, AVFileType.caf.rawValue, AVFileType.wav.rawValue, AVFileType.ac3.rawValue, AVFileType.eac3.rawValue]
}
