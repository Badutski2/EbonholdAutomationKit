# EbonholdAutomationKit

EbonholdAutomationKit is a Quality of Life AddOn made **for Ebonhold**.

## What it does
- Automates picking Echoes/Perks based on your setup (weighted scoring).
- Automates rerolling when a pick is weak (smart reroll handling).
- Automates banishing unwanted options (when configured to do so).
- Supports multiple profiles + import/export so you can swap setups quickly.
- Keeps a history/logbook so you can review what was picked and why.

## Installation
1. Download the latest release (or clone this repo).
2. Put the folder here:
   `Ebonhold/Interface/AddOns/`
3. Make sure the folder is named:
   `EbonholdAutomationKit`
4. Start the game and enable the AddOn.

## Settings
Configure it in-game. If something feels unsafe, turn it off..
Use **/eak** to open Interface Settings or use Game Menu.

## Known Issues
- Echo Picking can begin stuttering, restarting it will fix the issue.
- Sometimes picking fails, this will cause the AddOn to pause for 3 seconds to make up for server/client lag, so if nothing is being picked, banished or rolled, just give it a few seconds.

## Reporting bugs
If something breaks, include:
- What you were doing
- The full Lua error text
- Any relevant settings you had enabled