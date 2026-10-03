# AGY Limits Bar

AGY Limits Bar is a menu bar utility for macOS (and system tray app for Windows) that displays your current limits and quotas for Google Antigravity (agy).

## macOS Installation

1. **Prerequisites:** Ensure you have the `agy` CLI installed and authenticated.
2. **Build and Run:**
   - Clone the repository.
   - Run the `./build_app.sh` script to compile the Swift application.
   - It will generate an `AGY Limits Bar.app` bundle in the directory.
   - Open `AGY Limits Bar.app`.
   - Optional: Drag the `.app` bundle to your `Applications` folder and add it to Login Items (System Settings -> General -> Login Items) to start automatically.

## Windows Installation (Portable)

A self-contained, portable Windows executable (`AgyLimitsWindows.exe`) is available in the `AgyLimitsWindows` folder.

1. **Download:** Go to the `AgyLimitsWindows` folder and download `AgyLimitsWindows.zip`.
2. **Extract:** Extract the `.zip` file to get `AgyLimitsWindows.exe`.
3. **Run:** Double-click `AgyLimitsWindows.exe`. It will run in the system tray (bottom right, near the clock).
4. **Prerequisites:** Ensure the `agy` CLI is installed on Windows and accessible in your command line. The app dynamically searches for `~/.gemini` and `~/.agy-profile-*` folders in your `%USERPROFILE%`.

*Note: The Windows executable is large (~100 MB) because it packages the entire .NET runtime inside it, making it completely portable without requiring any .NET installations.*
