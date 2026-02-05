import Foundation

extension Dictionary where Key == String, Value == Any {
	func int(_ key: String) -> Int? {
		switch self[key] {
		case let v as Int: return v
		case let v as Int64: return Int(v)
		case let v as UInt64: return Int(v)
		case let v as NSNumber: return v.intValue
		default: return nil
		}
	}
	
	func int64(_ key: String) -> Int64? {
		switch self[key] {
		case let v as Int64: return v
		case let v as Int: return Int64(v)
		case let v as UInt64: return Int64(bitPattern: v)
		case let v as NSNumber: return v.int64Value
		default: return nil
		}
	}
	
	func bool(_ key: String) -> Bool? {
		switch self[key] {
		case let v as Bool: return v
		case let v as NSNumber: return v.boolValue
		default: return nil
		}
	}
	
	func string(_ key: String) -> String? {
		switch self[key] {
		case let v as String: return v
		case let v as NSString: return v as String
		default: return nil
		}
	}
	
	func dictionary(_ key: String) -> [String: Any]? {
		switch self[key] {
		case let v as [String: Any]: return v
		case let v as NSDictionary: return v as? [String: Any]
		default: return nil
		}
	}
}

extension NSDictionary {
	func string(_ key: String) -> String? {
		switch self[key] {
		case let v as String: return v
		case let v as NSString: return v as String
		default: return nil
		}
	}
}
