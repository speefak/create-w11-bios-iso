#!/bin/bash
# name          : create-w11-bios-iso.sh
# desciption    : create windows 11 install iso for bios installations (no UEFI)
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.3
# notice        :
# infosource    : ChatGPT / varios manuals
#
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

WIN10_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_10/Win10_22H2_German_x64v1.iso" #TODO interactive request for user enter path
WIN11_ISO="/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_11/Win11_24H2_German_x64.iso"	#TODO interactive request for user enter path

 IsoNameW11Bios="W11-BIOS-$(date +%F-%H%M%S).iso"
 
 RootDir="/home/create-w11-bios-iso-$(date +%F-%H%M%S)"
 WorkingDir="$RootDir/working-dir"
 IsoMountPoint="$RootDir/iso-mounts"
 IsoOutputfileW11="$(awk -F "/" '{for (i=1; i<NF; i++) printf "%s/", $i}' <<< $RootDir)$IsoNameW11Bios"

 RequiredPackets="git wimtools xorriso"

 SystemdServiceFile="/etc/systemd/system/vtuner-satip.service"
 CheckMark=$'\033[0;32m✔\033[0m'   # Grün ✔
 CrossMark=$'\033[0;31m✖\033[0m'   # Rot ✖

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------
load_color_codes () {
	Black='\033[0;30m' && DGray='\033[1;30m'
	LRed='\033[0;31m' && Red='\033[1;31m'
	LGreen='\033[0;32m' && Green='\033[1;32m'
	LYellow='\033[0;33m' && Yellow='\033[1;33m'
	LBlue='\033[0;34m' && Blue='\033[1;34m'
	LPurple='\033[0;35m' && Purple='\033[1;35m'
	LCyan='\033[0;36m' && Cyan='\033[1;36m'
	LLGrey='\033[0;37m' && White='\033[1;37m'
	Reset='\033[0m'
	BG='\033[47m'; FG='\033[0;30m'
}
#------------------------------------------------------------------------------------------------------------------------------------------------
check_for_required_packages () {
	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)
	for Packet in $RequiredPackets; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets="$MissingPackets $Packet"
		fi
	done
	if [[ -n $MissingPackets ]]; then
		printf "missing packets: $Red$MissingPackets$Reset \n"
		read -e -p "install required packets? (Y/N) " -i "Y" InstallMissingPackets
		if [[ $InstallMissingPackets =~ ^[Yy]$ ]]; then
			sudo apt update && sudo apt install -y $MissingPackets || exit 1
		else
			printf "programm error: $Red missing packets : $MissingPackets $Reset \n\n"
			exit 1
		fi
	else
		printf "$Green all required packets detected $Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_w11_bios_iso () {

	# create directoriesmkdir -p "$RootDir/W10-ISO-source"
	mkdir -p "$RootDir"
	mkdir -p "$WorkingDir"
	mkdir -p "$IsoMountPoint"
	mkdir -p "$IsoMountPoint"

	# --- Schritt 1: BIOS-bootfähige ISO erzeugen (Windows 10 source) ---
	printf "\n[1/3] Erzeuge Arbeitsverzeichnis mit Win10-Bootdateien...\n"
	sudo mount -o loop "$WIN10_ISO" "$IsoMountPoint"
	rsync -aH --info=progress2 "$IsoMountPoint"/ "$WorkingDir"/
	sudo umount "$IsoMountPoint"

	printf "\n[2/3] Ersetze Windows 10 install.wim durch Windows 11-Version...\n"
	sudo mount -o loop "$WIN11_ISO" "$IsoMountPoint"
	rm -f "$WorkingDir/sources/install.wim" "$WorkingDir/sources/install.esd"
	cp "$IsoMountPoint/sources/install.wim" "$WorkingDir/sources/"
	sudo umount "$IsoMountPoint"

	# Falls install.wim zu groß ist -> splitten
	WIM_FILE="$RootDir/W10-ISO-source/sources/install.wim"
	if [ -f "$WIM_FILE" ]; then
	    WIM_SIZE=$(stat -c%s "$WIM_FILE")
	    if [ "$WIM_SIZE" -gt 4294967295 ]; then
		echo "install.wim größer als 4 GB – splitte in SWM-Dateien..."
		wimlib-imagex split "$WIM_FILE" "$RootDir/W10-ISO-source/sources/install.swm" 4000
		rm "$WIM_FILE"
	    fi
	fi

	# ISO bauen
	printf "\n[3/3] Erstelle ISO-Datei: $IsoOutputfileW11 \n"
	xorriso -as mkisofs \
	  -iso-level 3 \
	  -V "$IsoNameW11Bios" \
	  -o "$IsoOutputfileW11" \
	  -b boot/etfsboot.com \
	  -no-emul-boot \
	  -boot-load-size 8 \
	  -boot-info-table \
	  "$WorkingDir"

	printf "\nISO-Erstellung abgeschlossen: $IsoOutputfileW11\n"

	printf "\nclear temporary files\n"
	rm -rf "$RootDir"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
write_iso_to_usb () {

 USB="/dev/sdc"   # ACHTUNG: anpassen!			#TODO abfrage und überprüfung opb wirklch nur usb geräte und prüfung das keine system partiotn verwendet wird
# --- Optional: USB-Stick beschreiben ---
read -p "Soll der USB-Stick $USB jetzt mit woeusb beschrieben werden? (y/N): " ANSW
if [[ "$ANSWER" == "y" || "$ANSWER" == "Y" ]]; then
    echo "ACHTUNG: $USB wird vollständig überschrieben!"
    sudo woeusb --device "$IsoOutputfileW11" "$USB"
    echo "USB-Stick erstellt: BIOS-/Legacy-bootfähig für Windows 11."
else
    echo "Überspringe USB-Erstellung. ISO liegt unter: $IsoOutputfileW11"
fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------



#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################

#------------------------------------------------------------------------------------------------------------

	if [[ "$(id -u)" -ne 0 ]]; then echo "Are you root?"; exit 1; fi

#------------------------------------------------------------------------------------------------------------

	load_color_codes
	check_for_required_packages
	create_w11_bios_iso
	# clear directories

#------------------------------------------------------------------------------------------------------------

	# write iso to usb
	#write_iso_to_usb


#------------------------------------------------------------------------------------------------------------


exit 0



#------------------------------------------------------------------------------------------------------------------------------------------------
#
# changelog
# 0.X - 0.3	TODO => write iso to usb, usind dd does not wird, xoriso, not work, woeusb works

# notice
#
