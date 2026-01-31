import Foundation

protocol BatteryReaderProtocol {
    func readSnapshot() async -> BatterySnapshot
}
