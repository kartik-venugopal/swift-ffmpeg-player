/*
    Customizes the look and feel of all non-ticked horizontal sliders
*/

import Cocoa

fileprivate let white40Percent: NSColor = NSColor(white: 0.4, alpha: 1)
fileprivate let white20Percent: NSColor = NSColor(white: 0.2, alpha: 1)
fileprivate let whiteIsh: NSColor = NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)

fileprivate let verticalGradientDegrees: CGFloat = -90.0
fileprivate let horizontalGradientDegrees: CGFloat = -180.0

fileprivate let backgroundGradient: NSGradient = NSGradient(starting: white40Percent, ending: white20Percent)!
fileprivate let foregroundGradient: NSGradient = NSGradient(starting: whiteIsh.darkened(20), ending: whiteIsh)!

// Cell for seek position slider
class SeekSliderCell: NSSliderCell {
    
    var barRadius: CGFloat {return 2}
    var barInsetX: CGFloat {return 0}
    var barInsetY: CGFloat {return 0}
    
    var knobColor: NSColor {whiteIsh}
    var knobRadius: CGFloat {return 2}
    var knobWidth: CGFloat {return 6}
    var knobHeightOutsideBar: CGFloat {return 6}
    
    // Returns the center of the current knob frame
    var knobCenter: CGFloat {
        return knobRect(flipped: false).centerX
    }
    
    override func barRect(flipped: Bool) -> NSRect {
        return super.barRect(flipped: flipped).insetBy(dx: barInsetX, dy: barInsetY)
    }
    
    override internal func drawBar(inside aRect: NSRect, flipped: Bool) {
        
        let knobFrame = knobRect(flipped: false)
        let halfKnobWidth = knobFrame.width / 2
        
        let leftRect = NSRect(x: aRect.minX, y: aRect.minY, width: max(halfKnobWidth, knobFrame.minX + halfKnobWidth), height: aRect.height)
        let leftRectPath = NSBezierPath(roundedRect: leftRect, xRadius: barRadius, yRadius: barRadius)
        foregroundGradient.draw(in: leftRectPath, angle: verticalGradientDegrees)
        
        let rightRect = NSRect(x: knobFrame.maxX - halfKnobWidth, y: aRect.minY, width: aRect.width - (knobFrame.maxX - halfKnobWidth), height: aRect.height)
        let rightRectPath = NSBezierPath(roundedRect: rightRect, xRadius: barRadius, yRadius: barRadius)
        backgroundGradient.draw(in: rightRectPath, angle: verticalGradientDegrees)
    }
    
    override func knobRect(flipped: Bool) -> NSRect {
        
        let bar = barRect(flipped: flipped)
        let val = CGFloat(self.doubleValue)
        
        let startX = bar.minX + (val * bar.width / 100)
        let xOffset = -(val * knobWidth / 100)
        
        let newX = startX + xOffset
        let newY = bar.minY - knobHeightOutsideBar
        
        return NSRect(x: newX, y: newY, width: knobWidth, height: knobHeightOutsideBar * 2 + bar.height)
    }
    
    override internal func drawKnob(_ knobRect: NSRect) {
        
        let bar = barRect(flipped: true)

        let knobHeight: CGFloat = bar.height + knobHeightOutsideBar
        let knobMinX = knobRect.minX
        let rect = NSRect(x: knobMinX, y: bar.minY - ((knobHeight - bar.height) / 2), width: knobWidth, height: knobHeight)

        let knobPath = NSBezierPath(roundedRect: rect, xRadius: knobRadius, yRadius: knobRadius)
        knobColor.setFill()
        knobPath.fill()
    }
}

// Cell for volume slider
class VolumeSliderCell: SeekSliderCell {
    
    override var barRadius: CGFloat {return 2}
    override var barInsetY: CGFloat {return 0}
    override var knobWidth: CGFloat {return 6}
    override var knobRadius: CGFloat {return 2}
    override var knobHeightOutsideBar: CGFloat {return 6}
    
    override func knobRect(flipped: Bool) -> NSRect {
        
        let bar = barRect(flipped: flipped)
        let val = CGFloat(self.doubleValue)
        
        let startX = bar.minX + (val * bar.width)
        let xOffset = -(val * knobWidth)
        
        let newX = startX + xOffset
        let newY = bar.minY - knobHeightOutsideBar
        
        return NSRect(x: newX, y: newY, width: knobWidth, height: knobHeightOutsideBar * 2 + bar.height)
    }
}

extension NSRect {
    
    var centerX: CGFloat {
        return self.minX + (self.width / 2)
    }
    
    var centerY: CGFloat {
        return self.minY + (self.height / 2)
    }
}

extension NSColor {
    
    // If necessary, converts this color to the RGB color space.
    func toRGB() -> NSColor {
        
        // Not in RGB color space, need to convert.
        if self.colorSpace.colorSpaceModel != .rgb, let rgb = self.usingColorSpace(.deviceRGB) {
            return rgb
        }
        
        // Already in RGB color space, no need to convert.
        return self
    }
    
    // Returns a color that is darker than this color by a certain percentage.
    // NOTE - The percentage parameter represents a percentage within the range of possible values.
    // eg. For black, the range would be zero, so this function would have no effect. For white, the range would be the entire [0.0, 1.0]
    // For a color in between black and white, the range would be [0, B] where B represents the brightness component of this color.
    func darkened(_ percentage: CGFloat) -> NSColor {
        
        let rgbSelf = self.toRGB()
        
        let curBrightness = rgbSelf.brightnessComponent
        let newBrightness = curBrightness - (percentage * curBrightness / 100)
        
        return NSColor(hue: rgbSelf.hueComponent, saturation: rgbSelf.saturationComponent, brightness: min(max(0, newBrightness), 1), alpha: rgbSelf.alphaComponent)
    }
    
    // Returns a color that is brighter than this color by a certain percentage.
    // NOTE - The percentage parameter represents a percentage within the range of possible values.
    // eg. For white, the range would be zero, so this function would have no effect. For black, the range would be the entire [0.0, 1.0]
    // For a color in between black and white, the range would be [B, 1.0] where B represents the brightness component of this color.
    func brightened(_ percentage: CGFloat) -> NSColor {
        
        let rgbSelf = self.toRGB()
        
        let curBrightness = rgbSelf.brightnessComponent
        let range: CGFloat = 1 - curBrightness
        let newBrightness = curBrightness + (percentage * range / 100)
        
        return NSColor(hue: rgbSelf.hueComponent, saturation: rgbSelf.saturationComponent, brightness: min(max(0, newBrightness), 1), alpha: rgbSelf.alphaComponent)
    }
}
