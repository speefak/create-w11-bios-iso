# Windows 11 BIOS ISO Creator

This script creates a **Windows 11 installation ISO** that is compatible with **BIOS/Legacy boot systems** (UEFI is not supported).  
Optionally, the generated ISO can be written directly to a USB drive to create a bootable installation media.  

The script combines files from an existing Windows 10 ISO with the Windows 11 installation image (`install.wim`) to produce a BIOS-compatible ISO suitable for installation.  

---

## Features

- Checks for and installs required packages (`git`, `wimtools`, `xorriso`).  
- Creates temporary working directories for ISO preparation.  
- Copies boot files from the Windows 10 ISO.  
- Replaces installation files with Windows 11 versions.  
- Splits large `install.wim` files into smaller `.swm` files if they exceed 4 GB.  
- Generates a new ISO file with the combined contents.  
- Optionally writes the ISO to a USB drive using `woeusb` to produce a bootable stick.  
- Cleans up temporary files after completion.  

---

## Requirements

- Linux (Debian/Ubuntu recommended)  
- Root privileges for ISO creation and USB writing  
- Installed packages: `git`, `wimtools`, `xorriso`  
- `dialog` for interactive menus  
