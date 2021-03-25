import Cocoa

/*
    Customizes the look and feel of the "Open File" button.
*/

class OpenDialogButtonCell: NSButtonCell {
    
    let imgOpenFile: NSImage = NSImage(named: "OpenFile")!
    
    let backgroundFillGradient: NSGradient = {
        
        let backgroundStart = NSColor(white: 0.5, alpha: 1)
        let backgroundEnd =  NSColor(white: 0.2, alpha: 1)
        return NSGradient(starting: backgroundStart, ending: backgroundEnd)!
    }()
    
    var textColor: NSColor = NSColor(white: 0.9, alpha: 1)
    
    let textFont: NSFont = NSFont.systemFont(ofSize: 14)
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        
        let drawRect = cellFrame
        
        // Background
        backgroundFillGradient.draw(in: drawRect, angle: 90)
        
        // Title
        drawCenteredTextInRect(drawRect, title, textColor, textFont, 0)
        
        imgOpenFile.draw(in: NSRect(x: drawRect.maxX - 35, y: 2, width: 26, height: 26))
    }
    
    // Draws text, centered, within an NSRect, with a certain font and color
    private func drawCenteredTextInRect(_ rect: NSRect, _ text: String, _ textColor: NSColor, _ font: NSFont, _ offset: CGFloat = 0) {
        
        let attrsDict: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor]
        
        // Compute size and origin
        let size: CGSize = text.size(withAttributes: attrsDict)
        let sx = (rect.width - size.width) / 2
        let sy = (rect.height - size.height) / 2 - 1
        
        text.draw(in: NSRect(x: sx, y: sy + offset, width: size.width, height: size.height), withAttributes: attrsDict)
    }
}
