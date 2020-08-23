import AVFoundation

///
/// A utlity that writes raw floating-point PCM samples to a file so that the output may be tested for fidelity in a program like Audacity.
/// This is for testing/debugging purposes only.
///
class BufferFileWriter {
    
    static let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/0bad.raw", "w+")
    static var ctr: Int = 0
    
    ///
    /// Writes all Float sample data from a single audio buffer to an output file that
    /// can be read as "Raw Data" by a program like Audacity.
    ///
    static func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        
        let numSamples = Int(buffer.frameLength)
        
        let data = buffer.floatChannelData

        for s in 0..<numSamples {

            for i in 0..<2 {
                
                fwrite(&data![i][s], MemoryLayout<Float>.size, 1, outfile)
                
                if (s > 44100 && s < 44200) {
                    print("\(s): \(data![i][s])");
                }
            }
        }
        
        print("\nWrote \(numSamples) samples. So far = \(ctr)")
    }

    ///
    /// Closes the output file.
    ///
    static func closeFile() {
        fclose(outfile)
    }
}
