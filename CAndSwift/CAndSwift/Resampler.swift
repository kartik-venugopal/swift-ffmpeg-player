//
//  AppDelegate.swift
//  UInt8
//
//  Created by Kven on 7/20/20.
//  Copyright © 2020 Kven. All rights reserved.
//

import Foundation

class Resampler {
    
    let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/test.raw", "w+")
    
    fileprivate let max32BitFloatVal: Float = Float(Int32.max)
    
    private func uint8() {
        
        let cnt: Int = 256 * 1
        
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: cnt)
        for index in (0..<cnt) {
            bytes[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }
        
        let fl8: Float = Float(Int8.max) + 0.5
        
        var floatsForChannel: [Float] = []
        
        let time = measureTime {
            floatsForChannel = (0..<cnt).map {(Float(bytes[$0]) / fl8) - 1}
        }
        
        print("Took \(time * 1000) msec to generate floats", floatsForChannel.filter {$0 > 1.0}.count, floatsForChannel.filter {$0 < -1.0}.count)
    }
    
    func clamp(_ val: Float) -> Float {
        min(1, max(val, -1))
    }
    
    private func int16() {
        
        let cnt: Int = 256 * 1
        
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: cnt * 2)
        for index in (0..<(cnt * 2)) {
            bytes[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }
        
        let fl16: Float = Float(Int16.max) + 0.5
        //        let fl16: Float = Float(Int16.max)
        
        print(Int16.min, Int16.max)
        
        var floatsForChannel: [Float] = []
        
        let ubytes = UnsafePointer(bytes)
        
        let time = measureTime {
            
            let reboundData: UnsafePointer<Int16> = ubytes.withMemoryRebound(to: Int16.self, capacity: cnt){$0}
            floatsForChannel = (0..<cnt).map {(Float(reboundData[$0]) + 0.5) / fl16}
        }
        
        let fil = floatsForChannel.filter {$0 < -1 || $0 > 1}
        print("Took \(time * 1000) msec to generate floats", fil.count, fil)
    }
    
    private func resample_U8_to_FLT() {
        
        let cnt: Int = 44100 * 5 * 2
        
        let in_num_samples: Int = cnt
        let in_num_samples_32: Int32 = Int32(cnt)
        
        var out_samples: UnsafeMutablePointer<UInt8>?
        
        let in_samples = UnsafeMutablePointer<UInt8>.allocate(capacity: in_num_samples)
        var uin_samples: UnsafePointer<UInt8>? = UnsafePointer(in_samples)
        
        for index in (0..<in_num_samples) {
            in_samples[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }
        
        var floats: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.allocate(capacity: 0)
        
        let time = measureTime {
            
            var swr: OpaquePointer? = swr_alloc()
            let uswr = UnsafeMutableRawPointer(swr)
            
            av_opt_set_channel_layout(uswr, "in_channel_layout", Int64(AV_CH_LAYOUT_MONO), 0)
            av_opt_set_channel_layout(uswr, "out_channel_layout", Int64(AV_CH_LAYOUT_MONO), 0)
            
            av_opt_set_int(uswr, "in_sample_rate", 44100, 0)
            av_opt_set_int(uswr, "out_sample_rate", 44100, 0)
            
            av_opt_set_sample_fmt(uswr, "in_sample_fmt", AV_SAMPLE_FMT_U8, 0)
            av_opt_set_sample_fmt(uswr, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0)
            
            swr_init(swr)
            
            var out_num_samples: Int32 = in_num_samples_32
            
            av_samples_alloc(&out_samples, nil, 1, out_num_samples, AV_SAMPLE_FMT_FLT, 1)
            out_num_samples = swr_convert(swr, &out_samples, out_num_samples, &uin_samples, in_num_samples_32)
            
            floats = out_samples!.withMemoryRebound(to: Float.self, capacity: cnt){$0}
            
            swr_free(&swr)
        }
        
        print("Time (Packed): \(time * 1000) msec")
        
        for index in (cnt - 25)..<cnt {
            print(index, ": ", in_samples[index], "->", floats[index])
        }
    }
    
    private func resample_S16_to_FLT() {
        
        let cnt: Int = 352800 * 5 * 6
        //        let cnt: Int = 100000
        
        let in_num_samples_32: Int32 = Int32(cnt)
        var out_num_samples: Int32 = in_num_samples_32
        
        let origSamples: [Int16] = (0..<cnt).map {_ in Int16.random(in: Int16.min...Int16.max)}
        let origPtr = UnsafeMutablePointer(mutating: origSamples)
        
        let num = origSamples[0]
        print(num, num.littleEndian, num.bigEndian)
        
        let in_samples = origPtr.withMemoryRebound(to: UInt8.self, capacity: cnt * 2){$0}
        var uin_samples: UnsafePointer<UInt8>? = UnsafePointer(in_samples)
        
        var out_samples: UnsafeMutablePointer<UInt8>?
        var floats: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.allocate(capacity: 0)
        
        var t2: Double = 0
        var t3: Double = 0
        
        let time = measureTime {
            
            var swr: OpaquePointer? = swr_alloc()
            let uswr = UnsafeMutableRawPointer(swr)
            
            av_opt_set_channel_layout(uswr, "in_channel_layout", Int64(AV_CH_LAYOUT_MONO), 0)
            av_opt_set_channel_layout(uswr, "out_channel_layout", Int64(AV_CH_LAYOUT_MONO), 0)
            
            av_opt_set_int(uswr, "in_sample_rate", 44100, 0)
            av_opt_set_int(uswr, "out_sample_rate", 44100, 0)
            
            av_opt_set_sample_fmt(uswr, "in_sample_fmt", AV_SAMPLE_FMT_S16P, 0)
            av_opt_set_sample_fmt(uswr, "out_sample_fmt", AV_SAMPLE_FMT_FLTP, 0)
            
            swr_init(swr)
            
            t2 = measureTime {
                
                av_samples_alloc(&out_samples, nil, 1, out_num_samples, AV_SAMPLE_FMT_FLT, 1)
                
                t3 = measureTime {
                    out_num_samples = swr_convert(swr, &out_samples, out_num_samples, &uin_samples, in_num_samples_32)
                }
            }
            
            floats = out_samples!.withMemoryRebound(to: Float.self, capacity: cnt){$0}
            
            swr_free(&swr)
        }
        
        print("Time (S16 -> FLT): \(time * 1000) msec")
        print("T2 (S16 -> FLT): \(t2 * 1000) msec")
        print("T3 (S16 -> FLT): \(t3 * 1000) msec", in_num_samples_32, out_num_samples)
        
        let start = Int.random(in: 0..<(cnt - 25))
        let indices = start..<(start + 25)
        
        for index in indices {
            print(index, ": ", origSamples[index], "->", floats[index])
        }
    }
    
    private func doResample_S16Packed_to_FLTPlanar(_ cnt: Int, _ inDataPtr: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>) {
        
        let in_num_samples_32: Int32 = Int32(cnt)
        let out_num_samples: Int32 = in_num_samples_32
        
        var swr: OpaquePointer? = swr_alloc()
        let uswr = UnsafeMutableRawPointer(swr)
        
        av_opt_set_channel_layout(uswr, "in_channel_layout", Int64(AV_CH_LAYOUT_STEREO), 0)
        av_opt_set_channel_layout(uswr, "out_channel_layout", Int64(AV_CH_LAYOUT_STEREO), 0)
        
        av_opt_set_int(uswr, "in_sample_rate", 44100, 0)
        av_opt_set_int(uswr, "out_sample_rate", 44100, 0)
        
        av_opt_set_sample_fmt(uswr, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0)
        av_opt_set_sample_fmt(uswr, "out_sample_fmt", AV_SAMPLE_FMT_FLTP, 0)
        
        swr_init(swr)
        
        // Destination
        
        let outDataPtr: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: outData, count: 4)
        
        _ = inDataPtr.withMemoryRebound(to: UnsafePointer<UInt8>?.self) { bufPtr in
            swr_convert(swr, outDataPtr.baseAddress, out_num_samples, bufPtr.baseAddress!, in_num_samples_32)
        }
        
        swr_free(&swr)
    }
    
    private func resample_S16Packed_to_FLTPlanar(_ cnt: Int) {
        
        let in_num_samples_32: Int32 = Int32(cnt)
        
        // Source
        
        let inData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 4)
        inData.initialize(to: nil)
        var linesize = 0 as Int32
        av_samples_alloc(inData, &linesize, 2, in_num_samples_32, AV_SAMPLE_FMT_S16, 0)
        
        let inDataPtr: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: inData, count: 4)
        
        // Fill source samples
        
        let ptr = UnsafeMutableRawPointer(inData[0]!).bindMemory(to: Int16.self, capacity: 2 * cnt)
        
        var orig: [Int16] = []
        
        for i in 0..<cnt {
            
            let sample = Int16.random(in: Int16.min...Int16.max)
            orig.append(sample)
            orig.append(sample / 2)
            
            ptr[i * 2 + 0] = sample
            ptr[i * 2 + 1] = sample / 2
        }
        
        let time = measureTime {
            doResample_S16Packed_to_FLTPlanar(cnt, inDataPtr)
        }
        
        print("\nResampling time: \(time * 1000) msec")
        
        let floats = outData[0]!.withMemoryRebound(to: Float.self, capacity: cnt){$0}
        let floats2 = outData[1]!.withMemoryRebound(to: Float.self, capacity: cnt){$0}
        
        let start = Int.random(in: 0..<(cnt - 25))
        let indices = start..<(start + 10)
        
        print("\nIndices: \(indices)")

        print("\nChannel 0:", indices.map {$0 * 2}.map {orig[$0]})

        for index in indices {
            print("\n\(index):", orig[index * 2], "->", floats[index])
        }

        print("\nChannel 1:", indices.map {$0 * 2 + 1}.map {orig[$0]})

        for index in indices {
            print("\n\(index):", orig[index * 2 + 1], "->", floats2[index])
        }
    }
    
    var outData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    func resample() {
        
        outData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 4)
        outData.initialize(to: nil)
        av_samples_alloc(outData, nil, 2, 352800 * 10 * 6, AV_SAMPLE_FMT_FLTP, 0)
        
        //        resample_S16_to_FLT()
        resample_S16Packed_to_FLTPlanar(44100 * 5 * 2)
        
        resample_S16Packed_to_FLTPlanar(48000 * 10 * 2)
        
        resample_S16Packed_to_FLTPlanar(352800 * 10 * 6)
        
        //        uint8()
        //        int16()
        
        //        print(uarr, "\n")
        //        print(sarr, "\n")
        
        //        print(5 == 5.bigEndian, 5 == 5.littleEndian)
        //
        //        let count = 5 * 44100 * 2
        //        let all: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        //
        //        for index in (0..<count) {
        //            all[index] = UInt8.random(in: UInt8.min...UInt8.max)
        //        }
        //
        //        let bytes = UnsafePointer(all)
        //        let reboundData: UnsafePointer<Int32> = bytes.withMemoryRebound(to: Int32.self, capacity: count){$0}
        //
        //        var time = measureTime {
        //            var floats: [Float] = (0..<count).map {Float(reboundData[$0]) / max32BitFloatVal}
        //        }
        //
        //        print(time * 1000)
        //
        //        time = measureTime {
        //            var floats: [Float] = (0..<count).map {Float(reboundData[$0])}
        //        }
        //
        //        print(time * 1000)
        
        //        let file: URL = URL(fileURLWithPath: "/Volumes/MyData/Music/Aural-Test/Reiki2.ogg")
        //
        //        do {
        //
        //            let avFile: AVAudioFile = try AVAudioFile(forReading: file)
        //            let fmt = avFile.processingFormat
        //            var aclSize : Int = 0
        //            let aclPtr : UnsafePointer<AudioChannelLayout>? =
        //                CMAudioFormatDescriptionGetChannelLayout(fmt.formatDescription, sizeOut: &aclSize)
        //
        //            var nameSize : UInt32 = 0
        //            _ =
        //                AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutName,
        //                                           UInt32(aclSize), aclPtr, &nameSize)
        //
        //            let count : Int = Int(nameSize) / MemoryLayout<CFString>.size
        //            let ptr : UnsafeMutablePointer<CFString> =
        //                UnsafeMutablePointer<CFString>.allocate(capacity: count)
        //
        //            _ =
        //                AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutName,
        //                                       UInt32(aclSize), aclPtr, &nameSize, ptr)
        //
        //            let formatString = String(ptr.pointee as NSString)
        //
        //            print(formatString)
        //            ptr.deallocate() // Is this same as CFRelease(cfstringref)?
        //
        //            AVAudioSettings.
        //
        //        } catch {
        //            print(error)
        //        }
    }
}

extension SignedInteger {
    
    mutating func toByteArray() -> [UInt8] {
        return withUnsafeBytes(of: &self, Array.init)
    }
}

extension Int16 {
    
    static func fromByteArray(_ array: [UInt8]) -> Self {
        return array.withUnsafeBytes {$0.load(as: Int16.self)}.littleEndian
    }
}
