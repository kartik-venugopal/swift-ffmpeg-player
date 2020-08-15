import AVFoundation
import Accelerate

protocol SampleConverterProtocol {
    
    func supports(format: SampleFormat) -> Bool
    
    func convert(samplesIn frameBuffer: FrameBuffer, andCopyTo audioBuffer: AVAudioPCMBuffer)
}

class SampleConverter: SampleConverterProtocol {
    
    private let avfConverter: AVFSampleConverter = AVFSampleConverter()
    private let ffmpegConverter: FFmpegSampleConverter = FFmpegSampleConverter()
    
    func supports(format: SampleFormat) -> Bool {
        return true
    }
    
    func convert(samplesIn frameBuffer: FrameBuffer, andCopyTo audioBuffer: AVAudioPCMBuffer) {
        
        if avfConverter.supports(format: frameBuffer.audioFormat.sampleFormat) {
            avfConverter.convert(samplesIn: frameBuffer, andCopyTo: audioBuffer)
            
        } else {
            ffmpegConverter.convert(samplesIn: frameBuffer, andCopyTo: audioBuffer)
        }
    }
}
