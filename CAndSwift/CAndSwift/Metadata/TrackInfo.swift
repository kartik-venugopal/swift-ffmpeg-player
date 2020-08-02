import Cocoa

struct TrackInfo {
    
    var audioInfo: AudioInfo
    var metadata: [String: String]
    
    var art: NSImage?
    var artMetadata: [String: String]?
    
    var chapters: [Chapter]
    
    var displayedTitle: String? {
        
        let title = self.title
        let artist = self.artist
        
        if let theArtist = artist, let theTitle = title {
            return "\(theArtist) - \(theTitle)"
            
        } else {
            return title
        }
    }
    
    var title: String? {
        metadata.filter {$0.key.lowercased() == "title"}.first?.value
    }
    
    var artist: String? {
        metadata.filter {$0.key.lowercased() == "artist"}.first?.value
    }
    
    var album: String? {
        metadata.filter {$0.key.lowercased() == "album"}.first?.value
    }
    
    var displayedTrackNum: String? {
        
        let trackNum = self.trackNum
        let trackTotal = self.trackTotal
        
        if let theTrackNum = trackNum, let theTrackTotal = trackTotal {
            return "\(theTrackNum) / \(theTrackTotal)"
            
        } else {
            return trackNum
        }
    }
    
    var trackNum: String? {
        metadata.filter {$0.key.lowercased() == "track"}.first?.value
    }
    
    var trackTotal: String? {
        
        metadata.filter {$0.key.lowercased() == "tracktotal"}.first?.value ??
        metadata.filter {$0.key.lowercased() == "totaltracks"}.first?.value
    }
    
    var displayedDiscNum: String? {
        
        let discNum = self.discNum
        let discTotal = self.discTotal
        
        if let theDiscNum = discNum, let theDiscTotal = discTotal {
            return "\(theDiscNum) / \(theDiscTotal)"
            
        } else {
            return discNum
        }
    }
    
    var discNum: String? {
        metadata.filter {$0.key.lowercased() == "disc"}.first?.value
    }
    
    var discTotal: String? {
        
        metadata.filter {$0.key.lowercased() == "disctotal"}.first?.value ??
        metadata.filter {$0.key.lowercased() == "totaldiscs"}.first?.value
    }
    
    var genre: String? {
        metadata.filter {$0.key.lowercased() == "genre"}.first?.value
    }
    
    var year: String? {
        
        metadata.filter {$0.key.lowercased() == "year"}.first?.value ??
        metadata.filter {$0.key.lowercased() == "date"}.first?.value
    }
    
    var otherMetadata: [String: String] {
        
        let excludedKeys = ["title", "artist", "album", "genre", "year", "date", "track", "disc", "tracktotal", "totaltracks", "disctotal", "totaldiscs"]
        
        return metadata.filter {!excludedKeys.contains($0.key.lowercased())}
    }
}

struct Chapter {
    
    var startTime: Double
    var endTime: Double
    var title: String
}

struct AudioInfo {
    
    var fileType: String
    var codec: String
    var duration: Double
    var sampleRate: Int
    var sampleFormat: SampleFormat
    var bitRate: Int64
    var channelCount: Int
    var frameCount: Int64
}
