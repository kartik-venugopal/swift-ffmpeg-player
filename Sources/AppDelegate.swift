import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var playerVC: PlayerViewController!
    
    override init() {
        
        super.init()
        configureLoggingToAFile()
    }
    
    private func configureLoggingToAFile() {
        freopen(NSHomeDirectory() + "/Music/ffmpeg-player.log", "a+", stderr)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        opQueue.maxConcurrentOperationCount = 14
        
        let dir: URL = URL(fileURLWithPath: "/Users/kven/Music")
//        let dir: URL = URL(fileURLWithPath: "/Volumes/MBP-Ext-4TB/Projects/Aural-Test")
        recurse(dir)
        opQueue.waitUntilAllOperationsAreFinished()
        
        print("\nFinished. MinRG = \(arr.min()), MaxRG = \(arr.max()), Avg = \(avg), numPosValues = \(arr.filter({$0 > 0}).count), totalCount = \(arr.count)")
        print("\n\(arr.sorted(by: <))")
//        print(map)
    }
    
    var avg: Float {
        
        var sum: Float = 0
        for num in arr {
            sum += num
        }
        
        return sum / Float(arr.count)
    }
    
    var ctr: AtomicCounter<Int> = .init()
    
    var arr: [Float] = []
    
    let opQueue = OperationQueue()
    
    private func recurse(_ dir: URL) {
        
        for file in dir.children ?? [] {
            
            if file.isDirectory {
                
                recurse(file)
                continue
            }
            
            //            if file.lowerCasedExtension != "mp3" {continue}
            let ext = file.lowerCasedExtension
                        if !Constants.audioFileExtensions.contains(ext) {continue}
//            if ext != "flac" {continue}
            
            opQueue.addOperation {
                
                guard let ffmpeg = AudioFileContext(forFile: file) else {return}
                
                let ctx = ffmpeg.format
                let metadata = ctx.metadata
                
//                let streamMetadata = ctx.bestAudioStream?.metadata ?? [:]
                let codec = ffmpeg.decoder.codec
                
                do {
                    try codec.open()
                    if metadata.contains(where: {key, value in key.lowercased().contains("replaygain_track_gain")}) && metadata.contains(where: {key, value in key.lowercased().contains("replaygain_track_peak")}) {
                        
//                        print("RG = \(replayGain.trackGain!), Peak = \(trackPeak) for: \(file.path)")
                        print("\(self.ctr.incrementAndGet()) - \(file.path)")
                    }
                    
                } catch {}
            }
        }
    }

    ///
    /// Relays the event of application termination to the PlayerViewController, so that it may take appropriate actions.
    ///
    func applicationWillTerminate(_ notification: Notification) {
        playerVC.applicationWillTerminate(notification)
    }
    
    ///
    /// Returning true here will cause the app to terminate when the main window is closed instead of continuing to run.
    ///
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {true}
}

//
//  URLExtensions.swift
//  Aural
//
//  Copyright © 2024 Kartik Venugopal. All rights reserved.
//
//  This software is licensed under the MIT software license.
//  See the file "LICENSE" in the project root directory for license terms.
//
import Foundation
import Cocoa

extension URL {
    
    static let ascendingPathComparator: (URL, URL) -> Bool = {$0.path < $1.path}
    
    private static let fileManager: FileManager = .default
    
    private var fileManager: FileManager {Self.fileManager}
    
    var nameWithoutExtension: String {
        deletingPathExtension().lastPathComponent
    }
    
    // Retrieves the contents of a directory
    var children: [URL]? {
        
        guard exists, isDirectory else {return nil}
        
        do {
            // Retrieve all files/subfolders within this folder
            return try fileManager.contentsOfDirectory(at: self, includingPropertiesForKeys: [],
                                                       options: .skipsHiddenFiles)
            
        } catch let error as NSError {
            
            NSLog("Error retrieving contents of directory '%@': %@", self.path, error.description)
            return nil
        }
    }
    
    func findFileWithoutExtensionNamed(_ fileName: String) -> URL? {
        children?.first(where: {$0.nameWithoutExtension == fileName})
    }
    
    // Deletes a file / directory recursively (i.e. all children will be deleted, if it is a directory).
    func delete(recursive: Bool = true) {
        
        guard exists else {return}
        
        do {
            
            if recursive {
                
                // First delete this file's children (if any).
                for file in self.children ?? [] {
                    try fileManager.removeItem(atPath: file.path)
                }
            }
            
            // Delete this file.
            try fileManager.removeItem(atPath: self.path)
            
        } catch let error as NSError {
            NSLog("Error deleting file '%@': %@", self.path, error.description)
        }
    }
    
    // Renames this file
    func rename(to target: URL) {
        
        do {
            try fileManager.moveItem(at: self, to: target)
        } catch let error as NSError {
            NSLog("Error renaming file '%@' to '%@': %@", self.path, target.path, error.description)
        }
    }
}
