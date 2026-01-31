import SwiftUI
import AppKit

struct BatteryPopoverView: View {
    @ObservedObject var monitor: BatteryMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppleMetrics.sectionGap) {
            Text("Battery Monitor")
                .font(.headline)
                .padding(.top, 12)
                .padding(.horizontal, AppleMetrics.popoverPadH)
            
            VStack(spacing: 0) {
                let presenter = BatteryPopoverPresenter(snapshot: monitor.snapshot)
                let lines = presenter.buildInfoLines()
                
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, s in
                    AppleInfoLine(text: s)
                }
            }
            .padding(.horizontal, AppleMetrics.popoverPadH)
            
            Divider().padding(.horizontal, AppleMetrics.popoverPadH)
            
            let apps = monitor.significantEnergyApps
            let empty = apps.isEmpty
            
            if !empty {
                Text("Using Significant Energy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .padding(.horizontal, AppleMetrics.popoverPadH)
            }
            
            VStack(spacing: 0) {
                if empty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        
                        Text("No Apps Using Significant Energy")
                            .font(.system(size: AppleMetrics.bodySize, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppleMetrics.rowPadV)
                    .padding(.horizontal, AppleMetrics.popoverPadH)
                } else {
                    ForEach(Array(apps.enumerated()), id: \.offset) { idx, app in
                        AppleRowButton(app.name, icon: app.icon) {
                            revealAppInFinder(appName: app.name)
                        }.padding(.horizontal, 6)
                    }
                }
            }
            
            Divider().padding(.horizontal, AppleMetrics.popoverPadH)
            
            VStack(spacing: 0) {
                AppleRowButton("GitHub Page") {
                    openGithubPage()
                }
                AppleRowButton("Check for Updates") {
                    checkForUpdates()
                }
                AppleRowButton("Battery Settings…") {
                    openBatterySettings()
                }
                
                AppleRowButton("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(.bottom, 6)
            .padding(.horizontal, 6)
        }
        .frame(minWidth: 240, maxWidth: 300, alignment: .leading)
        .onAppear { monitor.startPolling() }
        .onDisappear { monitor.stopPolling() }
    }
    
    private func openBatterySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Battery") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func revealAppInFinder(appName: String) {
        let appPath = "/Applications/\(appName).app"
        let url = URL(fileURLWithPath: appPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func openGithubPage() {
        if let url = URL(string: "https://github.com/CrashSystemZ/ChargeMonitor/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/CrashSystemZ/ChargeMonitor/releases/latest") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                showError(message: "Failed to check for updates")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let latestVersion = json["tag_name"] as? String {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
                    
                    if latestVersion > "v\(currentVersion)" {
                        showInfo(message: "New version \(latestVersion) is available! Download it from GitHub")
                    } else {
                        showInfo(message: "You are up to date")
                    }
                }
            } catch {
                showError(message: "Error parsing update information. Please try again later")
            }
        }
        task.resume()
    }
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            
            alert.messageText = ""
            alert.informativeText = message
            
            alert.runModal()
        }
    }
    
    private func showInfo(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "GitHub")

            alert.messageText = ""
            alert.informativeText = message

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
               openGithubPage()
            }
        }
    }
}
