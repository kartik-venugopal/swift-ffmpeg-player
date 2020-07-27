//do {
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
