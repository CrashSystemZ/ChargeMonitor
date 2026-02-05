import AppKit
import Darwin
import Foundation

struct SignificantEnergyApp: Identifiable {
	let id: String
	let pid: pid_t
	let name: String
	let bundleIdentifier: String
	let bundleURL: URL?
	let icon: NSImage?
	let energyImpact: Double
}

struct ProcessMetrics {
	let cpuTimeSeconds: Double
	let wakeups: UInt64
	let diskReadBytes: UInt64
	let diskWriteBytes: UInt64
}

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t, _ responsible: UnsafeMutablePointer<pid_t>) -> Int32

final class SignificantEnergyReader {
	private struct EnergyState {
		var ema: Double
		var sampleCount: Int
		var isSignificant: Bool
	}
	
	private var previousByPid: [pid_t: ProcessMetrics] = [:]
	private var previousTimestamp: TimeInterval?
	private var stateByBundleId: [String: EnergyState] = [:]
	
	private let alpha: Double = 0.05
	private let appearThreshold: Double = 1.5
	private let disappearThreshold: Double = 1.0
	private let minPerProcessImpact: Double = 0.5
	private let minSamplesToShow: Int = 50
	
	private let cpuWeight: Double = 1.0
	private let wakeupWeight: Double = 0.02
	private let diskWeight: Double = 1.0e-7
	
	private let ignoredBundleIdPrefixes: [String] = [
		"com.apple.preference",
		"com.apple.systempreferences",
		"com.apple.controlcenter",
		"com.apple.notificationcenterui"
	]
	
	func computeSignificantApps() -> [SignificantEnergyApp] {
		let now = ProcessInfo.processInfo.systemUptime
		let runningApps = loadRunningRegularApps()
		let appsByBundlePath = mapAppsByBundlePath(runningApps)
		let dt = timeDeltaSeconds(now: now)
		
		let currentByPid = sampleAllProcesses()
		let energyByBundleId = dt.map { aggregateEnergyImpact(dt: $0, currentByPid: currentByPid, appsByBundlePath: appsByBundlePath) } ?? [:]
		
		previousByPid = currentByPid
		previousTimestamp = now
		
		updateState(runningApps: runningApps, energyByBundleId: energyByBundleId)
		
		let results = buildResults(from: runningApps)
		cleanupState(keeping: Set(runningApps.compactMap(\.bundleIdentifier)))
		
		return results.sorted { $0.energyImpact > $1.energyImpact }
	}
	
	private func loadRunningRegularApps() -> [NSRunningApplication] {
		NSWorkspace.shared.runningApplications.compactMap { app in
			guard !app.isTerminated else { return nil }
			guard app.activationPolicy == .regular else { return nil }
			guard let bundleIdentifier = app.bundleIdentifier else { return nil }
			guard !isIgnored(bundleIdentifier) else { return nil }
			guard app.bundleURL?.pathExtension == "app" else { return nil }
			return app
		}
	}
	
	private func mapAppsByBundlePath(_ apps: [NSRunningApplication]) -> [String: NSRunningApplication] {
		var map: [String: NSRunningApplication] = [:]
		for app in apps {
			guard let path = app.bundleURL?.path else { continue }
			map[path] = app
		}
		return map
	}
	
	private func timeDeltaSeconds(now: TimeInterval) -> TimeInterval? {
		guard let previousTimestamp else { return nil }
		let dt = now - previousTimestamp
		return dt > 0 ? dt : nil
	}
	
	private func sampleAllProcesses() -> [pid_t: ProcessMetrics] {
		var result: [pid_t: ProcessMetrics] = [:]
		for pid in listAllPids() {
			guard let metrics = readProcessMetrics(pid: pid) else { continue }
			result[pid] = metrics
		}
		return result
	}
	
	private func aggregateEnergyImpact(
		dt: TimeInterval,
		currentByPid: [pid_t: ProcessMetrics],
		appsByBundlePath: [String: NSRunningApplication]
	) -> [String: Double] {
		var energyByBundleId: [String: Double] = [:]
		
		for (pid, current) in currentByPid {
			guard let previous = previousByPid[pid] else { continue }
			let impact = energyImpact(current: current, previous: previous, dt: dt)
			guard impact >= minPerProcessImpact else { continue }
			
			guard let bundleId = resolveOwningBundleIdentifier(pid: pid, appsByBundlePath: appsByBundlePath) else { continue }
			energyByBundleId[bundleId, default: 0] += impact
		}
		
		return energyByBundleId
	}
	
	private func updateState(runningApps: [NSRunningApplication], energyByBundleId: [String: Double]) {
		for app in runningApps {
			let bundleId = app.bundleIdentifier ?? ""
			guard !bundleId.isEmpty else { continue }
			
			let currentEnergy = energyByBundleId[bundleId] ?? 0
			let prev = stateByBundleId[bundleId] ?? EnergyState(ema: currentEnergy, sampleCount: 0, isSignificant: false)
			
			let ema = alpha * currentEnergy + (1 - alpha) * prev.ema
			let sampleCount = prev.sampleCount + 1
			
			let isSignificant: Bool = {
				if prev.isSignificant { return ema >= disappearThreshold }
				return ema >= appearThreshold
			}()
			
			stateByBundleId[bundleId] = EnergyState(ema: ema, sampleCount: sampleCount, isSignificant: isSignificant)
		}
	}
	
	private func buildResults(from runningApps: [NSRunningApplication]) -> [SignificantEnergyApp] {
		let currentAppBundleId = Bundle.main.bundleIdentifier
		var results: [SignificantEnergyApp] = []
		
		for app in runningApps {
			guard let bundleId = app.bundleIdentifier else { continue }
			if bundleId == currentAppBundleId { continue }
			
			guard let state = stateByBundleId[bundleId] else { continue }
			guard state.sampleCount >= minSamplesToShow else { continue }
			guard state.isSignificant else { continue }
			
			let name = app.localizedName
			?? app.bundleURL?.deletingPathExtension().lastPathComponent
			?? "Unknown"
			
			let icon: NSImage? = app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
			
			results.append(
				SignificantEnergyApp(
					id: bundleId,
					pid: app.processIdentifier,
					name: name,
					bundleIdentifier: bundleId,
					bundleURL: app.bundleURL,
					icon: icon,
					energyImpact: state.ema
				)
			)
		}
		
		return results
	}
	
	private func cleanupState(keeping runningBundleIds: Set<String>) {
		stateByBundleId = stateByBundleId.filter { runningBundleIds.contains($0.key) }
	}
	
	private func isIgnored(_ bundleIdentifier: String) -> Bool {
		ignoredBundleIdPrefixes.contains { bundleIdentifier.hasPrefix($0) }
	}
	
	private func resolveOwningBundleIdentifier(
		pid: pid_t,
		appsByBundlePath: [String: NSRunningApplication]
	) -> String? {
		if let bundleId = bundleIdentifierFromProcess(pid: pid, appsByBundlePath: appsByBundlePath) {
			return bundleId
		}
		
		guard let responsiblePid = responsiblePid(for: pid), responsiblePid != pid else { return nil }
		return bundleIdentifierFromProcess(pid: responsiblePid, appsByBundlePath: appsByBundlePath)
	}
	
	private func bundleIdentifierFromProcess(
		pid: pid_t,
		appsByBundlePath: [String: NSRunningApplication]
	) -> String? {
		guard
			let execPath = processPath(pid: pid),
			let rootAppPath = rootAppBundlePath(from: execPath),
			let app = appsByBundlePath[rootAppPath]
		else { return nil }
		
		return app.bundleIdentifier
	}
	
	private func rootAppBundlePath(from execPath: String) -> String? {
		let components = execPath.split(separator: "/").map(String.init)
		
		for (index, component) in components.enumerated() where component.hasSuffix(".app") {
			let path = components.prefix(index + 1).joined(separator: "/")
			return path.isEmpty ? nil : "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		}
		
		return nil
	}
	
	private func responsiblePid(for pid: pid_t) -> pid_t? {
		var responsible: pid_t = 0
		let result = responsibility_get_pid_responsible_for_pid(pid, &responsible)
		guard result == 0, responsible > 0 else { return nil }
		return responsible
	}
	
	private func energyImpact(current: ProcessMetrics, previous: ProcessMetrics, dt: TimeInterval) -> Double {
		let cpuDelta = current.cpuTimeSeconds - previous.cpuTimeSeconds
		guard cpuDelta >= 0 else { return 0 }
		
		let cpuPercent = (cpuDelta / dt) * 100.0
		let cpuImpact = cpuPercent * cpuWeight
		
		let wakeupsDelta = current.wakeups > previous.wakeups ? Double(current.wakeups - previous.wakeups) : 0
		let wakeupImpact = (wakeupsDelta / dt) * wakeupWeight
		
		let readDelta = current.diskReadBytes > previous.diskReadBytes ? Double(current.diskReadBytes - previous.diskReadBytes) : 0
		let writeDelta = current.diskWriteBytes > previous.diskWriteBytes ? Double(current.diskWriteBytes - previous.diskWriteBytes) : 0
		let diskImpact = (readDelta + writeDelta) * diskWeight / dt
		
		return cpuImpact + wakeupImpact + diskImpact
	}
	
	private func listAllPids() -> [pid_t] {
		let capacity = 4096
		var pids = [pid_t](repeating: 0, count: capacity)
		
		let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
		guard bytes > 0 else { return [] }
		
		let count = Int(bytes) / MemoryLayout<pid_t>.stride
		return pids.prefix(count).filter { $0 > 0 }
	}
	
	private func processPath(pid: pid_t) -> String? {
		var buffer = [CChar](repeating: 0, count: 4096)
		let count = proc_pidpath(pid, &buffer, UInt32(buffer.count))
		guard count > 0 else { return nil }
		return String(cString: buffer)
	}
	
	private func readProcessMetrics(pid: pid_t) -> ProcessMetrics? {
		var info = rusage_info_current()
		
		let result: Int32 = withUnsafeMutablePointer(to: &info) { infoPtr in
			infoPtr.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: 1) { rawPtr in
				proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rawPtr)
			}
		}
		
		guard result == 0 else { return nil }
		
		let cpuTimeNS = info.ri_user_time + info.ri_system_time
		let cpuTimeSeconds = Double(cpuTimeNS) / 1_000_000_000.0
		
		return ProcessMetrics(
			cpuTimeSeconds: cpuTimeSeconds,
			wakeups: info.ri_pkg_idle_wkups,
			diskReadBytes: info.ri_diskio_bytesread,
			diskWriteBytes: info.ri_diskio_byteswritten
		)
	}
}

