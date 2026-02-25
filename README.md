# Reaper-Regions-To-Projects

A REAPER script to automatically create separate projects from regions. Perfect for splitting multitrack recordings into organized subprojects.

## Features

- **Batch Subproject Creation**: Convert selected regions (or all regions) into individual subproject files
- **Automatic Bus Track**: Creates a "Subproject Bus" track to organize all subproject items
- **Original Item Handling**: Choose what happens to items moved into each subproject:
  - **Replace**: Delete original items from the region (clean slate)
  - **Preserve**: Mute original items in place (safe backup in case you need them)
- **Master FX Bypass**: Automatically bypasses the master FX chain in subprojects to prevent double processing
- **Progress Tracking**: Real-time progress bar in the console during batch processing
- **Async Processing**: Non-blocking execution allows you to continue working while subprojects are created
- **Auto-Cleanup**: Removes temporary project files, keeping only the imported snapshots

## Installation

### Option 1: Manual Installation

1. Download `make_subprojects_from_regions.lua` from this repository
2. Place it in your REAPER Scripts folder:
   - **Windows**: `%APPDATA%\REAPER\Scripts\`
   - **macOS**: `~/Library/Application Support/REAPER/Scripts/`
   - **Linux**: `~/.config/REAPER/Scripts/`
3. Refresh REAPER's script list (Actions → Show action list → Refresh script list)
4. The script will appear in the Actions menu as "Make subprojects from regions"

### Option 2: ReaPack Installation

1. If you don't have ReaPack installed, get it from [here](https://reapack.com/)
2. In REAPER, open ReaPack (Extensions → ReaPack → Browse packages)
3. Search for "Regions to Subprojects" or add this repository URL:
   ```
   https://github.com/dylan-robins/Reaper-Regions-To-Projects
   ```
4. Install the script and it will auto-update with new versions

## Usage

1. Create regions in your REAPER project that mark the boundaries for each subproject
2. (Optional) Select specific regions if you only want to process those; otherwise all regions will be processed
3. Run the script (Actions → Make subprojects from regions)
4. Choose your item handling preference (Replace or Preserve)
5. Wait for the progress to complete

The script will:
- Create a new project file for each region
- Trim each subproject to the region boundaries
- Create a new "Subproject Bus" track if it doesn't exist
- Insert each subproject as an item on the bus track at the correct time
- Delete or mute original items that fall within the region based on your choice

## Notes

- Subproject files are automatically cleaned up after import; only the `-imported` versions remain
- Master FX chains are bypassed in subprojects to prevent double processing
- Each operation is undoable as a single undo action
- Requires REAPER 6.82 or later