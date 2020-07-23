import AVFoundation

class BufferFileWriter {
    
    static let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/bad.raw", "w+")
    static var ctr: Int = 0
    
    static func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        
        let numSamples = Int(buffer.frameLength)
        ctr += numSamples
        
//        let data = buffer.floatChannelData
        let data = buffer.int16ChannelData

        for s in 0..<numSamples {

            for i in 0..<2 {
//                fwrite(&data![i][s], MemoryLayout<Float>.size, 1, outfile)
                fwrite(&data![i][s], MemoryLayout<Int16>.size, 1, outfile)
            }
        }
        
        print("\nWrote \(numSamples) samples. So far = \(ctr)")
    }
    
    static func closeFile() {
        fclose(outfile)
    }
}
