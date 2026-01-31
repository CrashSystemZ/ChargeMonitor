import AppKit
import Darwin
import Foundation

struct SignificantEnergyApp: Identifiable {
    let id: String
    let pid: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let energyImpact: Double
}

struct ProcessMetrics {
    let cpuTime: Double
    let wakeups: UInt64
    let diskReadBytes: UInt64
    let diskWriteBytes: UInt64
}

private let PROC_PIDPATHINFO_MAXSIZE: Int = 4096

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t, _ responsible: UnsafeMutablePointer<pid_t>) -> Int32

final class SignificantEnergyReader {
    private var previousSamples: [pid_t: ProcessMetrics] = [:]
    private var previousTimestamp: TimeInterval = 0
    
    private var energyEMA: [String: Double] = [:]
    private var samplesCount: [String: Int] = [:]
    
    private var isSignificant: [String: Bool] = [:]
    
    private let alpha: Double = 0.05
    private let appearThreshold: Double = 1.5
    private let disappearThreshold: Double = 1.0
    private let minThreshold: Double = 0.5
    private let minSamplesToShow: Int = 50
    
    private let cpuWeight: Double = 1.0
    private let wakeupWeight: Double = 0.02
    private let diskWeight: Double = 1.0e-7
    
    private let ignoredBundlePrefixes: [String] = [
        "com.apple.preference",
        "com.apple.systempreferences",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui"
    ]
    
    func computeSignificantApps() -> [SignificantEnergyApp] {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = previousTimestamp > 0 ? now - previousTimestamp : 0
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated &&
            $0.bundleURL?.pathExtension == "app" &&
            $0.bundleIdentifier != nil
        }
        
        let allApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            
            for prefix in ignoredBundlePrefixes {
                if bundleId.hasPrefix(prefix) { return false }
            }
                        
            return app.activationPolicy == .regular
        }
        
        var bundlePathToApp: [String: NSRunningApplication] = [:]
        for app in allApps {
            if let bundlePath = app.bundleURL?.path {
                bundlePathToApp[bundlePath] = app
            }
        }
        
        let allPids = getAllPids()
        
        var currentSamples: [pid_t: ProcessMetrics] = [:]
        var appEnergyImpact: [String: Double] = [:]
        
        for pid in allPids {
            guard let metrics = readProcessMetrics(pid: pid) else { continue }
            
            currentSamples[pid] = metrics
            
            if dt > 0, let previous = previousSamples[pid] {
                let energyImpact = calculateEnergyImpact(current: metrics, previous: previous, dt: dt)
                
                if energyImpact > minThreshold, let bundleId = findParentApp(pid: pid, bundlePathToApp: bundlePathToApp) {
                    appEnergyImpact[bundleId, default: 0] += energyImpact
                }
            }
        }
        
        previousSamples = currentSamples
        previousTimestamp = now
        
        let runningBundleIds = Set(allApps.compactMap { $0.bundleIdentifier })
        
        for bundleId in runningBundleIds {
            let currentEnergy = appEnergyImpact[bundleId] ?? 0
            let previousEMA = energyEMA[bundleId] ?? currentEnergy
            let newEMA = alpha * currentEnergy + (1 - alpha) * previousEMA
            
            energyEMA[bundleId] = newEMA
            samplesCount[bundleId, default: 0] += 1
        }
        
        var result: [SignificantEnergyApp] = []
        
        for app in allApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            if bundleId == Bundle.main.bundleIdentifier { continue }
            
            guard let ema = energyEMA[bundleId] else { continue }
            guard let samples = samplesCount[bundleId], samples >= minSamplesToShow else { continue }
            
            let wasSignificant = isSignificant[bundleId] ?? false
            let nowSignificant = wasSignificant
            ? ema >= disappearThreshold
            : ema >= appearThreshold
            
            isSignificant[bundleId] = nowSignificant
            
            guard nowSignificant else { continue }
            
            let name = app.localizedName ?? (app.bundleURL?.deletingPathExtension().lastPathComponent ?? "Unknown")
            
            var icon: NSImage? = nil
            if let bundleURL = app.bundleURL {
                icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            }
            
            result.append(SignificantEnergyApp(
                id: bundleId,
                pid: app.processIdentifier,
                name: name,
                bundleIdentifier: bundleId,
                icon: icon,
                energyImpact: ema
            ))
        }
        
        energyEMA = energyEMA.filter { runningBundleIds.contains($0.key) }
        samplesCount = samplesCount.filter { runningBundleIds.contains($0.key) }
        isSignificant = isSignificant.filter { runningBundleIds.contains($0.key) }
        
        result.sort { $0.energyImpact > $1.energyImpact }
        return result
    }
    
    private func findParentApp(
        pid: pid_t,
        bundlePathToApp: [String: NSRunningApplication]
    ) -> String? {
        if let execPath = getProcessPath(pid: pid),
           let rootAppPath = extractRootAppBundle(from: execPath),
           let app = bundlePathToApp[rootAppPath] {
            return app.bundleIdentifier
        }
        
        if let responsiblePid = getResponsiblePid(pid: pid),
           responsiblePid != pid,
           let path = getProcessPath(pid: responsiblePid),
           let rootAppPath = extractRootAppBundle(from: path),
           let app = bundlePathToApp[rootAppPath] {
            return app.bundleIdentifier
        }
        
        return nil
    }
    
    private func extractRootAppBundle(from path: String) -> String? {
        let components = path.components(separatedBy: "/")
        
        for (index, component) in components.enumerated() {
            if component.hasSuffix(".app") {
                let appPath = components.prefix(through: index).joined(separator: "/")
                return appPath.isEmpty ? nil : appPath
            }
        }
        
        return nil
    }
    
    private func getResponsiblePid(pid: pid_t) -> pid_t? {
        var responsible: pid_t = 0
        let result = responsibility_get_pid_responsible_for_pid(pid, &responsible)
        guard result == 0, responsible > 0 else { return nil }
        return responsible
    }
    
    private func calculateEnergyImpact(current: ProcessMetrics, previous: ProcessMetrics, dt: TimeInterval) -> Double {
        let cpuDelta = current.cpuTime - previous.cpuTime
        guard cpuDelta >= 0 else { return 0 }
        
        let cpuPercent = (cpuDelta / dt) * 100.0
        let cpuImpact = cpuPercent * cpuWeight
        
        let wakeupsDelta = current.wakeups > previous.wakeups ? Double(current.wakeups - previous.wakeups) : 0
        let wakeupImpact = (wakeupsDelta / dt) * wakeupWeight
        
        let diskReadDelta = current.diskReadBytes > previous.diskReadBytes ? Double(current.diskReadBytes - previous.diskReadBytes) : 0
        let diskWriteDelta = current.diskWriteBytes > previous.diskWriteBytes ? Double(current.diskWriteBytes - previous.diskWriteBytes) : 0
        let diskImpact = (diskReadDelta + diskWriteDelta) * diskWeight / dt
        
        return cpuImpact + wakeupImpact + diskImpact
    }
    
    private func getAllPids() -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: PROC_PIDPATHINFO_MAXSIZE)
        let bytesReturned = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        let count = Int(bytesReturned) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(count).filter { $0 > 0 })
    }
    
    private func getProcessPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: PROC_PIDPATHINFO_MAXSIZE)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard ret > 0 else { return nil }
        return String(cString: buffer)
    }
    
    private func readProcessMetrics(pid: pid_t) -> ProcessMetrics? {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { infoPtr -> Int32 in
            infoPtr.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: 1) { reboundPtr in
                return proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, reboundPtr)
            }
        }
        guard result == 0 else { return nil }
        
        let cpuTimeNS = info.ri_user_time + info.ri_system_time
        let cpuTimeSec = Double(cpuTimeNS) / 1_000_000_000.0
        
        return ProcessMetrics(
            cpuTime: cpuTimeSec,
            wakeups: info.ri_pkg_idle_wkups,
            diskReadBytes: info.ri_diskio_bytesread,
            diskWriteBytes: info.ri_diskio_byteswritten
        )
    }
}
