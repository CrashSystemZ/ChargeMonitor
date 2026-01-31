import Foundation

enum IOUtils {
    static func intValue(_ any: Any?) -> Int? {
        switch any {
        case let v as Int: return v
        case let v as Int64: return Int(v)
        case let v as UInt64: return Int(v)
        case let v as NSNumber: return v.intValue
        default: return nil
        }
    }

    static func boolValue(_ any: Any?) -> Bool? {
        switch any {
        case let v as Bool: return v
        case let v as NSNumber: return v.boolValue
        default: return nil
        }
    }

    static func stringValue(_ any: Any?) -> String? {
        switch any {
        case let v as String: return v
        case let v as NSString: return v as String
        default: return nil
        }
    }
}
