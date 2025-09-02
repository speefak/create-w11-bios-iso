#!/bin/bash
# name          : create-w11-bios-iso.sh
# desciption    : create windows 11 install iso for bios installations (no UEFI)
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.2
# notice        :
# infosource    : ChatGPT / varios manuals
#
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------


set -e

# ISO-Dateien und Pfade anpassen
WIN10_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_10/Win10_22H2_German_x64v1.iso"
WIN11_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_11/Win11_24H2_German_x64.iso"
MNT="/mnt/W11_BIOS_INSTALL_IMAGE"
WORK="$HOME/win10_bios"
USB="/dev/sdc"   # Anpassen: Gerät des USB-Sticks

# Vorbereitung
mkdir -p "$WORK" "$MNT"
sudo umount "$MNT" 2>/dev/null || true

# Windows 10 ISO einhängen und kopieren
sudo mount -o loop "$WIN10_ISO" "$MNT"
rsync -aH --info=progress2 "$MNT"/ "$WORK"/
sudo umount "$MNT"

# Windows 11 ISO einhängen und Installationsabbild übernehmen
sudo mount -o loop "$WIN11_ISO" "$MNT"
rm -f "$WORK/sources/install.wim" "$WORK/sources/install.esd"
cp "$MNT/sources/install.wim" "$WORK/sources/"
sudo umount "$MNT"

# Prüfung: Falls install.wim > 4 GB → Aufteilung in SWM-Dateien
WIM_FILE="$WORK/sources/install.wim"
if [ -f "$WIM_FILE" ]; then
    WIM_SIZE=$(stat -c%s "$WIM_FILE")
    if [ "$WIM_SIZE" -gt 4294967295 ]; then
        echo "install.wim größer als 4 GB – wird in mehrere SWM-Dateien aufgeteilt..."
        wimlib-imagex split "$WIM_FILE" "$WORK/sources/install.swm" 4000
        rm "$WIM_FILE"
    fi
fi

# Übertragung auf USB-Stick mit woeusb
echo "ACHTUNG: Das Zielgerät $USB wird vollständig überschrieben!"
sudo woeusb --device "$WORK" "$USB"

echo "Vorgang abgeschlossen – der USB-Stick ist BIOS-/Legacy-bootfähig für Windows 11."

