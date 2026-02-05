<p align="center">
  <img width="128" height="128" alt="AppIcon-iOS-Dark-128x128@1x"
       src="https://github.com/user-attachments/assets/97cff96a-0a80-4f75-a4fc-4b8feb237421" />
</p>

<h1 align="center">ChargeMonitor</h1>

<p align="center">
  A lightweight macOS menu bar utility that surfaces real-time battery insights
  and highlights apps with significant energy impact.
</p>

## Why
Built‑in indicators provide only basic status. ChargeMonitor gathers more context at a glance so you can understand what drains your battery and how charging is going.

## Features
- Menu bar item with compact battery percentage.
- Popover with extended details:
  - power source and adapter name/manufacturer (when available);
  - charging state and time remaining to full (when available);
  - charging power (W) and fast‑charging indicator;
  - battery metrics like cycle count and maximum capacity (if available);
  - "Using Significant Energy": apps with noticeable energy impact.
- Quick actions:
  - open the project’s GitHub page;
  - check for updates (via GitHub Releases);
  - open system Battery Settings;
  - quit the app.

## How it works
- Battery data is read from system power sources and the smart battery interface:
  - power source, charging state, time to full;
  - cycles, estimated maximum capacity, charging power.
- «Significant energy» is determined heuristically from process metrics:
  - CPU time, wakeups, disk activity;
  - exponential moving average (EMA) with appearance/disappearance thresholds;
  - mapping PID → app by executable path or responsible process.

## Install & Run
  - Using Homebrew:
  ```bash
  brew install --cask CrashSystemZ/chargemonitor/chargemonitor
  ```
  Homebrew will always install the latest official release.
  <p>
    OR
  </p>

  - Download the latest release from GitHub.
  - Move the app to /Applications.
  - Launch ChargeMonitor — the menu bar will show the battery percentage; click to open the popover.

The app runs as an accessory (no Dock icon) and requires no extra permissions.

## Tips & Limitations
- Time to full is available only while charging and when the system provides it.
- The «significant energy» view is a heuristic meant to be stable and useful, not a precise replica of system telemetry.
- Some system processes and panels are intentionally filtered to keep the list focused on user apps.

## Privacy
ChargeMonitor does not send any data to external servers. Update checks go only to the public GitHub Releases API and do not include personal data.

## Contributing
- Please file issues for bugs and ideas.
- PRs are welcome: from heuristic tuning to UI/UX improvements.

## Screenshots
<p>
  <img width="331" height="297" alt="Screenshot 1"
       src="https://github.com/user-attachments/assets/a7431b93-0d88-460f-aba9-5eb19a2f590c" />
</p>
<p>
  <img width="332" height="361" alt="Screenshot 2" 
       src="https://github.com/user-attachments/assets/2752b0be-5e0d-4c5b-9ae9-f5a5520de538" />
</p>
