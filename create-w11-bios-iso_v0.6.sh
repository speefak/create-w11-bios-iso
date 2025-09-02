#!/bin/bash
# name          : create-w11-bios-iso.sh
# description   : create Windows 11 install ISO for BIOS installations (no UEFI)
# author        : speefak (itoss@gmx.de)
# license       : (CC) BY-NC-SA
# version       : 0.6
# notice        :
# source info   : ChatGPT / various manuals
#
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

WIN10_ISO= #"/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_10/Win10_22H2_German_x64v1.iso"
WIN11_ISO= #"/mnt/Archiv_Software/Betriebssysteme/Windows/Windows_11/Win11_24H2_German_x64.iso"	

IsoNameW11Bios="W11-BIOS-$(date +%F-%H%M%S).iso"

RootDir="/home/create-w11-bios-iso-$(date +%F-%H%M%S)"
WorkingDir="$RootDir/working-dir"
IsoMountPoint="$RootDir/iso-mounts"
IsoOutputfileW11="$(awk -F "/" '{for (i=1; i<NF; i++) printf "%s/", $i}' <<< $RootDir)$IsoNameW11Bios"

RequiredPackets="git wimtools xorriso dialog"

CheckMark=$'\033[0;32m✔\033[0m'   # Green ✔
CrossMark=$'\033[0;31m✖\033[0m'   # Red ✖

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
		printf "Missing packages: $Red$MissingPackets$Reset \n"
		read -e -p "Install required packages? (Y/N) " -i "Y" InstallMissingPackets
		if [[ $InstallMissingPackets =~ ^[Yy]$ ]]; then
			sudo apt update && sudo apt install -y $MissingPackets || exit 1
		else
			printf "Program error: $Red missing packages: $MissingPackets $Reset \n\n"
			exit 1
		fi
	else
		printf "$Green All required packages detected $Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
validate_windows_iso () {
	ISO_PATH="$1"
	ISO_NAME="$2"

	if [[ ! -f "$ISO_PATH" ]]; then
		dialog --msgbox "$ISO_NAME ISO not found: $ISO_PATH" 8 50
		return 1
	fi

	if ! file "$ISO_PATH" | grep -qi "ISO 9660"; then
		dialog --msgbox "$ISO_NAME ISO is not a valid ISO file: $ISO_PATH" 8 50
		return 1
	fi

	TMP_MOUNT=$(mktemp -d)
	sudo mount -o loop "$ISO_PATH" "$TMP_MOUNT"&>/dev/null || {
		dialog --msgbox "Failed to mount $ISO_NAME ISO: $ISO_PATH" 8 50
		rm -rf "$TMP_MOUNT"
		return 1
	}

	if [[ ! -d "$TMP_MOUNT/sources" || ! -f "$TMP_MOUNT/setup.exe" ]]; then
		dialog --msgbox "$ISO_NAME ISO does not appear to be a valid Windows ISO: $ISO_PATH" 8 50
		sudo umount "$TMP_MOUNT" &>/dev/null
		rm -rf "$TMP_MOUNT"
		return 1
	fi

	sudo umount "$TMP_MOUNT" &>/dev/null
	rm -rf "$TMP_MOUNT"

	echo "$ISO_NAME ISO verified: $ISO_PATH"
	return 0

	printf "Using Windows 10 ISO:$Green $WIN10_ISO $Reset"
	printf "Using Windows 11 ISO:$Green $WIN11_ISO $Reset"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
prepare_iso_paths () {
	mkdir -p cdroot

	# Windows 10 ISO abfragen
	if [[ -z "$WIN10_ISO" || ! -f "$WIN10_ISO" ]]; then
		while true; do
			WIN10_ISO=$(dialog --inputbox "Enter full path to Windows 10 ISO:" 10 60 2>&1 >/dev/tty)
			if [[ -f "$WIN10_ISO" ]]; then
				break
			else
				dialog --msgbox "File not found. Please try again." 8 40
			fi
		done
	fi

	# Windows 11 ISO abfragen
	if [[ -z "$WIN11_ISO" || ! -f "$WIN11_ISO" ]]; then
		while true; do
		WIN11_ISO=$(dialog --inputbox "Enter full path to Windows 11 ISO:" 10 60 2>&1 >/dev/tty)
		if [[ -f "$WIN11_ISO" ]]; then
			break
		else
			dialog --msgbox "File not found. Please try again." 8 40
		fi
		done
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_w11_bios_iso () {

	# create directories
	mkdir -p "$RootDir"
	mkdir -p "$WorkingDir"
	mkdir -p "$IsoMountPoint"

	# --- Step 1: create working directory with Windows 10 boot files ---
	printf "\n[1/3] Creating working directory with Win10 boot files...\n"
	sudo mount -o loop "$WIN10_ISO" "$IsoMountPoint"
	rsync -aH --info=progress2 "$IsoMountPoint"/ "$WorkingDir"/
	sudo umount "$IsoMountPoint"

	# --- Step 2: replace Windows 10 install.wim with Windows 11 version ---
	printf "\n[2/3] Replacing Windows 10 install.wim with Windows 11 version...\n"
	sudo mount -o loop "$WIN11_ISO" "$IsoMountPoint"
	rm -f "$WorkingDir/sources/install.wim" "$WorkingDir/sources/install.esd"
	cp "$IsoMountPoint/sources/install.wim" "$WorkingDir/sources/"
	sudo umount "$IsoMountPoint"

	# If install.wim is too large -> split into SWM files
	WimFile="$RootDir/W10-ISO-source/sources/install.wim"
	if [ -f "$WimFile" ]; then
		WimSize=$(stat -c%s "$WimFile")
		if [ "$WimSize" -gt 4294967295 ]; then
			printf "install.wim larger than 4 GB – splitting into SWM files...\n"
			wimlib-imagex split "$WimFile" "$RootDir/W10-ISO-source/sources/install.swm" 4000
			rm "$WimFile"
		fi
	fi

	# --- Step 3: create ISO ---
	printf "\n[3/3] Creating ISO file: $IsoOutputfileW11 \n"
	xorriso -as mkisofs \
		-iso-level 3 \
		-V "$IsoNameW11Bios" \
		-o "$IsoOutputfileW11" \
		-b boot/etfsboot.com \
		-no-emul-boot \
		-boot-load-size 8 \
		-boot-info-table \
		"$WorkingDir"

	printf "\nISO creation completed: $IsoOutputfileW11\n"

	printf "\nCleaning temporary files ...\n"
	rm -rf "$RootDir"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
write_iso_to_usb() {
	clear
	dialog --backtitle "Windows 11 BIOS ISO Tool" \
		--title "ISO to USB" \
		--menu "Choose an action:" 15 60 4 \
		1 "Write ISO to USB stick" \
		2 "Keep ISO only (skip USB)" 2>choice.txt

	CHOICE=$(<choice.txt)
	rm -f choice.txt
	clear

	case $CHOICE in
	1)
		# --- Detect USB drives ---
		USB_LIST=$(lsblk -d -o NAME,SIZE,MODEL,TRAN | tail -n +2 | grep "usb$")

		if [[ -z "$USB_LIST" ]]; then
			dialog --msgbox "No USB devices detected!" 8 50
			return 1
		fi

		# --- Build dialog menu ---
		MENU_ITEMS=()
		while read -r LINE; do
			# Remove last field (TRAN)
			ENTRY=$(echo "$LINE" | sed 's/ usb$//')
			DEV=$(echo "$ENTRY" | awk '{print $1}')
			DESC=$(echo "$ENTRY" | cut -d' ' -f2-)
			MENU_ITEMS+=("$DEV" "$DESC")
		done <<< "$USB_LIST"

		dialog  --backtitle "Windows 11 BIOS ISO Tool" \
			--title "Select USB Device" \
			--menu "Choose a target USB drive:" 20 70 10 \
			"${MENU_ITEMS[@]}" 2>usb_choice.txt

		USBDEV=$(<usb_choice.txt)
		rm -f usb_choice.txt

		if [[ -z "$USBDEV" ]]; then
			echo "No USB device selected. Aborted."
			return 1
		fi
		USB="/dev/$USBDEV"

		# --- Confirmation ---
		dialog --yesno "WARNING: All data on $USB will be ERASED!\n\nProceed?" 10 50
			if [[ $? -ne 0 ]]; then
			echo "Aborted by user."
			return 1
		fi

		# --- Unmount partitions ---
		for part in $(lsblk -ln -o NAME "$USB" | tail -n +2); do
			sudo umount "/dev/$part" 2>/dev/null
		done

		# --- Ensure woeusb exists ---
		if [[ ! -x ./woeusb-5.2.4.bash ]]; then
			echo "Downloading woeusb..."
			wget -q https://github.com/WoeUSB/WoeUSB/releases/download/v5.2.4/woeusb-5.2.4.bash -O woeusb-5.2.4.bash || {
			dialog --msgbox "Failed to download woeusb!" 8 40
			return 1
			}
			chmod +x woeusb-5.2.4.bash
		fi

		# --- Write ISO ---
		sudo ./woeusb-5.2.4.bash --device "$IsoOutputfileW11" "$USB"
		if [[ $? -eq 0 ]]; then
			dialog --msgbox "USB stick successfully created:\n$USB" 8 50
		else
			dialog --msgbox "Error writing ISO to USB!" 8 40
			return 1
		fi

		# --- Clear temporary files
		rm -rf "$RootDir"
		dialog --msgbox "Temporary files cleaned." 8 40
		exit 0
		;;
	2)
		dialog --msgbox "ISO kept only.\nFile is located at:\n$IsoOutputfileW11" 10 60
		;;
		*)
		echo "Invalid choice. Aborting."
		;;
	esac
}
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	if [[ "$(id -u)" -ne 0 ]]; then echo "Please run as root!"; exit 1; fi

#------------------------------------------------------------------------------------------------------------

	# Create windows 11 install iso (bios) using windows 10 bios installer
	load_color_codes
	check_for_required_packages
	prepare_iso_paths
	validate_windows_iso "$WIN10_ISO" "Windows 10"
	validate_windows_iso "$WIN11_ISO" "Windows 11"
	create_w11_bios_iso

#------------------------------------------------------------------------------------------------------------

	# write iso to usb
	write_iso_to_usb

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
#
# changelog
# 0.X - 0.3	TODO => write iso to usb, using dd does not work, xoriso works, woeusb works
#

