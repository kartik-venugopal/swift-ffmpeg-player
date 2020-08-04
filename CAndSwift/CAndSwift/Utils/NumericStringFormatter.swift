import Foundation

class NumericStringFormatter {
    
    ///
    /// Formats a number representing a time duration in seconds, to a string showing (rounded) hours, minutes, seconds, and optionally milliseconds.
    ///
    /// Example - A time duration of 257.79823431 seconds will be formatted to "4:18" or "4:17.798" (if milliseconds is included).
    /// Example - A time duration of 4129.18769 seconds will be formatted to "1:08:49" or "1:08:49.188" (if milliseconds is included).
    ///
    /// - Parameter timeSeconds: A time duration in seconds. The value to be formatted.
    ///
    /// - Parameter includeMsec: A (optional) boolean flag indicating whether or not the formatted string should include the milliseconds
    ///                             component of the specified time duration. False if not specified.
    ///
    static func formatSecondsToHMS(_ timeSeconds: Double, _ includeMsec: Bool = false) -> String {
        
        let intTimeSeconds = Int(round(timeSeconds))
        
        let secs = intTimeSeconds % 60
        let mins = (intTimeSeconds / 60) % 60
        let hrs = intTimeSeconds / 3600
        
        if includeMsec {
            
            let msec = Int(round((timeSeconds - floor(timeSeconds)) * 1000))
            return hrs > 0 ? String(format: "%d : %02d : %02d.%03d", hrs, mins, secs, msec) : String(format: "%d : %02d.%03d", mins, secs, msec)
            
        } else {
            return hrs > 0 ? String(format: "%d : %02d : %02d", hrs, mins, secs) : String(format: "%d : %02d", mins, secs)
        }
    }
    
    ///
    /// Formats an integer number with commas to make the displayed numeric string more readable to a user.
    ///
    /// Example - A value of 12345678 will be formatted to "12,345,678".
    /// Example - A value of 4096 will be formatted to "4,096".
    ///
    /// - Parameter number: An integer value. The value to be formatted.
    ///
    static func readableLongInteger(_ number: Int64) -> String {
        
        let numString = String(number)
        if numString.count <= 3 {return numString}
        
        var readableNumString: String = ""
        
        // Length of numString
        let numDigits: Int = numString.count
        
        for (characterIndex, character) in numString.enumerated() {
            
            readableNumString.append(character)

            if (numDigits - characterIndex > 3) && ((numDigits - characterIndex) % 3 == 1) {
                readableNumString.append(",")
            }
        }
        
        return readableNumString
    }
}
