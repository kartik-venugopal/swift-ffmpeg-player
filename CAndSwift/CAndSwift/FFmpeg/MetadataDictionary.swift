import Foundation

///
/// Reads metadata from an AVDictionary.
///
class MetadataDictionary {

    ///
    /// A dictionary of String key / value pairs produced by reading the underlying AVDictionary.
    ///
    let dictionary: [String: String]
    
    init(pointer: OpaquePointer!) {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(pointer, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        self.dictionary = metadata
    }
}
