import AVFoundation

class BufferFileWriter {
    
    static let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/0bad.raw", "w+")
    static var ctr: Int = 0
    
    static func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        
        let numSamples = Int(buffer.frameLength)
        
        let data = buffer.floatChannelData

        for s in 0..<numSamples {

            for i in 0..<2 {
                
                fwrite(&data![i][s], MemoryLayout<Float>.size, 1, outfile)
                ctr += 1
                
//                if (ctr > 44100 && ctr < 44200) {
//                    print("\(ctr): \(data![i][s])");
//                }
            }
        }
        
        print("\nWrote \(numSamples) samples. So far = \(ctr)")
    }
    
    static func closeFile() {
        fclose(outfile)
    }
}
