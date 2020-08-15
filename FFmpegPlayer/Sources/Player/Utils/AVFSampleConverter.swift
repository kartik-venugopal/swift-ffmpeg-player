import AVFoundation
import Accelerate

class AVFSampleConverter: SampleConverterProtocol {
    
    private let supportedFormats: [AVSampleFormat] = [AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P, AV_SAMPLE_FMT_FLT]
    
    func supports(format: SampleFormat) -> Bool {
        return supportedFormats.contains(format.avFormat)
//        return false
    }
    
    func convert(samplesIn frameBuffer: FrameBuffer, andCopyTo audioBuffer: AVAudioPCMBuffer) {
        
        // ----------- Step 1: Create a (temporary) input buffer to hold the unconverted PCM samples. -----------------
        
        let audioFormat = frameBuffer.audioFormat
        guard let inFormat = AVAudioFormat(from: audioFormat.sampleFormat, sampleRate: audioFormat.sampleRate,
                                           channelLayoutId: audioFormat.channelLayout) else {return}
        
        let frameLength = AVAudioFrameCount(frameBuffer.sampleCount)
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frameLength) else {return}
        inBuffer.frameLength = frameLength
        
        guard let converter = AVAudioConverter(from: inBuffer.format, to: audioBuffer.format) else {return}
        
        // ----------- Step 2: Copy the unconverted PCM samples to the input buffer. -----------------
        
        switch audioFormat.sampleFormat.avFormat {
            
        case AV_SAMPLE_FMT_S16:
            
            copySamples(in: frameBuffer, ofType: Int16.self, to: inBuffer.int16ChannelData)
            
        case AV_SAMPLE_FMT_S16P:
            
            copySamples(in: frameBuffer, ofType: Int16.self, to: inBuffer.int16ChannelData)
            
        case AV_SAMPLE_FMT_S32:
            
            copySamples(in: frameBuffer, ofType: Int32.self, to: inBuffer.int32ChannelData)
            
        case AV_SAMPLE_FMT_S32P:
            
            copySamples(in: frameBuffer, ofType: Int32.self, to: inBuffer.int32ChannelData)
            
        default:
            
            return
        }
        
        // ----------- Step 3: Perform the format conversion. ----------------------------------------
        
        do {
            
            try converter.convert(to: audioBuffer, from: inBuffer)
            
        } catch {
            print("\nConversion failed: \(error)")
        }
        
        audioBuffer.frameLength = frameLength
    }
    
    private func copySamples<T>(in frameBuffer: FrameBuffer, ofType: T.Type, to buffer: UnsafePointer<UnsafeMutablePointer<T>>?) where T: SignedInteger {
        
        var sampleCountSoFar: Int = 0
        let channelCount: Int = Int(frameBuffer.audioFormat.channelCount)
        let isInterleaved: Bool = frameBuffer.audioFormat.sampleFormat.isInterleaved
        let stride: Int = isInterleaved ? channelCount : 1
        
        for frame in frameBuffer.frames {
            
            let intSampleCount: Int = Int(frame.sampleCount)
            let intFirstSampleIndex: Int = Int(frame.firstSampleIndex)
            
            for channelIndex in 0..<channelCount {
                
                // Get the pointers to the source and destination buffers for the copy operation.
                guard let srcBytesForChannel = frame.dataPointers[channelIndex],
                let audioBufferChannel = buffer?[channelIndex] else {break}
                
                _ = srcBytesForChannel.withMemoryRebound(to: T.self, capacity: intSampleCount * stride) {
                    (intsForChannel: UnsafeMutablePointer<T>) in
                    
                    memcpy(audioBufferChannel.advanced(by: sampleCountSoFar * stride), intsForChannel.advanced(by: intFirstSampleIndex * stride),
                           intSampleCount * stride * MemoryLayout<T>.size)
                }
            }
            
            sampleCountSoFar += intSampleCount
        }
    }
    
//    private func copyInterleavedSamples<T>(in frameBuffer: FrameBuffer, ofType: T.Type, to buffer: UnsafePointer<UnsafeMutablePointer<T>>?) where T: SignedInteger {
//
//           guard let audioBufferChannels = buffer else {return}
//
//           var sampleCountSoFar: Int = 0
//           let channelCount: Int = Int(frameBuffer.audioFormat.channelCount)
//
//           for frame in frameBuffer.frames {
//
//               let intSampleCount: Int = Int(frame.sampleCount)
//               let intFirstSampleIndex: Int = Int(frame.firstSampleIndex)
//
//               for channelIndex in 0..<channelCount {
//
//                   // Get the pointers to the source and destination buffers for the copy operation.
//                   guard let srcBytesForChannel = frame.dataPointers[channelIndex] else {break}
//                   let audioBufferChannel = audioBufferChannels[channelIndex]
//
//                   _ = srcBytesForChannel.withMemoryRebound(to: T.self, capacity: intSampleCount * channelCount) {
//                       (intsForChannel: UnsafeMutablePointer<T>) in
//
//                       memcpy(audioBufferChannel.advanced(by: sampleCountSoFar * channelCount), intsForChannel.advanced(by: intFirstSampleIndex * channelCount),
//                              intSampleCount * channelCount * MemoryLayout<T>.size)
//                   }
//               }
//
//               sampleCountSoFar += intSampleCount
//           }
//       }
}
