import Foundation

///
/// The number of physical CPU cores in the system.
///
let systemNumberOfCores: Int = {
    
    var cores: Int = 1
    sysctlbyname("hw.physicalcpu", nil, &cores, nil, 0)
    return max(cores, 1)
}()

///
/// Extensions that provide helper functions or properties for added convenience.
///

extension BinaryInteger {
    
    mutating func clamp(minValue: Self, maxValue: Self) {
        
        if self < minValue {
            self = minValue
            
        } else if self > maxValue {
            self = maxValue
        }
    }
    
    mutating func clamp(minValue: Self) {
        
        if self < minValue {
            self = minValue
        }
    }
    
    mutating func clamp(maxValue: Self) {
        
        if self > maxValue {
            self = maxValue
        }
    }
}

///
/// Measures the execution time of a code block, in milliseconds (rounded to 2 decimal digits).
/// Useful for estimating performance of a function or code block when profiling / testing / debugging.
///
/// - Parameter task: The code block whose execution time is to be measured.
///
func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    
    let msecs = (CFAbsoluteTimeGetCurrent() - startTime) * 100000
    let rnd = Int(round(msecs))
    return Double(rnd) / 100.0
}
