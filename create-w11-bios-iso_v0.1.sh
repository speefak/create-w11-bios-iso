#!/bin/bash
# name          : create-w11-bios-iso.sh
# desciption    : create windows 11 install iso for bios installations (no UEFI)
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.1
# notice        :
# infosource    : ChatGPT / varios manuals
#
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

#!/bin/bash
# Variablen anpassen
WIN10_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_10/Win10_22H2_German_x64v1.iso"
WIN11_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_11/Win11_24H2_German_x64.iso"
MNT="/mnt/other"
WORK="$HOME/win11_bios"
OUT="$HOME/Win11_BIOS.iso"
USB="/dev/sdc"  # USB-Stick anpassen

# 1) Vorbereitung
mkdir -p "$WORK" "$MNT"
sudo umount "$MNT" 2>/dev/null || true

# 2) Windows 10 ISO einhängen und kopieren
sudo mount -o loop "$WIN10_ISO" "$MNT"
rsync -aH --info=progress2 "$MNT"/ "$WORK"/
sudo umount "$MNT"

# 3) Windows 11 install.wim kopieren
sudo mount -o loop "$WIN11_ISO" "$MNT"
rm -f "$WORK/sources/install.wim" "$WORK/sources/install.esd"
cp "$MNT/sources/install.wim" "$WORK/sources/"
sudo umount "$MNT"

# 4) install.wim splitten, falls >4GB
WIM_FILE="$WORK/sources/install.wim"
if [ -f "$WIM_FILE" ]; then
    WIM_SIZE=$(stat -c%s "$WIM_FILE")
    if [ "$WIM_SIZE" -gt 4294967295 ]; then
        echo "install.wim >4GB, splitten..."
        sudo apt install -y wimtools
        wimlib-imagex split "$WIM_FILE" "$WORK/sources/install.swm" 4000
        rm "$WIM_FILE"
    fi
fi

# 5) BIOS-bootfähige ISO erzeugen
xorriso -as mkisofs \
  -iso-level 3 \
  -V "Win11_BIOS" \
  -o "$OUT" \
  -b boot/etfsboot.com \
  -no-emul-boot \
  -boot-load-size 8 \
  -boot-info-table \
  "$WORK"

# 6) ISO auf USB-Stick schreiben (löscht Stick!)
echo "Achtung: USB-Stick $USB wird gelöscht!"
sudo dd if="$OUT" of="$USB" bs=4M status=progress conv=fsync

echo "Fertig! USB-Stick ist BIOS/Legacy-bootfähig für Windows 11."

