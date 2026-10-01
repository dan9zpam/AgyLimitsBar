# AGY Limits Bar

A lightweight, native macOS menu bar application (Status Bar App) that tracks your Google Antigravity (AGY) API limits and active account in real-time. 

## Features
- Displays a dynamic lightning bolt icon in the status bar that changes color based on your remaining 5-hour quota.
- Shows your current active `agy` account so you always know which quota you are burning.
- Fetches real-time quota data via the `agy` CLI.
- Fully native SwiftUI `MenuBarExtra` application.

## How to Build & Run
Simply execute the included shell script:
```bash
./build_app.sh
```
This will compile the Swift code, create an `.app` bundle, and you can run it directly:
```bash
open "AGY Limits Bar.app"
```

## Requirements
- macOS 13.0 or later.
- `agy` (Antigravity CLI) installed locally.
