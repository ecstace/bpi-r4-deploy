#!/bin/sh
# install-nvme.sh — BPI-R4 NVMe install script

NVME_DEV="/dev/nvme0n1"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 NVMe Installer\n"
printf "=================================================\n"
printf "\n"

# ¦¦ 1. NVMe device check ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

printf "[ 1/5 ] Checking NVMe device...\n"

if [ ! -b "$NVME_DEV" ]; then
    printf "\n"
    printf "${RED}ERROR: NVMe disk not found (%s does not exist).${NC}\n" "$NVME_DEV"
    printf "       Check physical connection and reboot.\n"
    printf "\n"
    exit 1
fi

printf "        OK -- found %s\n" "$NVME_DEV"
printf "\n"

# ¦¦ 2. SMART health check ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

printf "[ 2/5 ] Checking disk health (SMART)...\n"
printf "\n"

SMART_OUT=$(smartctl -a "$NVME_DEV" 2>/dev/null)

if [ -z "$SMART_OUT" ]; then
    printf "${YELLOW}WARNING: Could not read SMART data -- smartctl failed.${NC}\n"
    printf "         Skipping disk health check.\n"
    printf "\n"
    SMART_SKIP=1
fi

if [ -z "$SMART_SKIP" ]; then

    FAIL=0
    WARN=0

    # --- Model / serial / capacity (info) ---
    MODEL=$(echo "$SMART_OUT" | grep "Model Number"       | sed 's/.*: *//')
    SERIAL=$(echo "$SMART_OUT" | grep "Serial Number"     | sed 's/.*: *//')
    CAPACITY=$(echo "$SMART_OUT" | grep "Total NVM Capacity" | sed 's/.*: *//')
    printf "        Disk    : %s\n" "$MODEL"
    printf "        Serial  : %s\n" "$SERIAL"
    printf "        Capacity: %s\n" "$CAPACITY"
    printf "\n"

    # --- HARD FAIL checks ---

    # 1) SMART overall health
    HEALTH=$(echo "$SMART_OUT" | grep "SMART overall-health" | grep -o "PASSED\|FAILED")
    if [ "$HEALTH" = "FAILED" ]; then
        printf "${RED}  [FAIL] SMART overall-health: FAILED${NC}\n"
        printf "         Disk reports a critical failure. Installation not possible.\n"
        FAIL=1
    else
        printf "${GREEN}  [ OK ] SMART overall-health: PASSED${NC}\n"
    fi

    # 2) Critical Warning
    CRIT=$(echo "$SMART_OUT" | grep "Critical Warning" | awk '{print $NF}')
    if [ "$CRIT" != "0x00" ] && [ -n "$CRIT" ]; then
        printf "${RED}  [FAIL] Critical Warning: %s${NC}\n" "$CRIT"
        printf "         Disk has an active critical problem. Installation not possible.\n"
        FAIL=1
    else
        printf "${GREEN}  [ OK ] Critical Warning: %s${NC}\n" "$CRIT"
    fi

    # 3) Available Spare
    SPARE=$(echo "$SMART_OUT" | grep "Available Spare:" | grep -v Threshold | awk '{print $NF}' | tr -d '%')
    if [ -n "$SPARE" ] && [ "$SPARE" -lt 10 ]; then
        printf "${RED}  [FAIL] Available Spare: %s%%${NC}\n" "$SPARE"
        printf "         Disk has no spare cells remaining. Installation not possible.\n"
        FAIL=1
    else
        printf "${GREEN}  [ OK ] Available Spare: %s%%${NC}\n" "$SPARE"
    fi

    # 4) Percentage Used
    USED=$(echo "$SMART_OUT" | grep "Percentage Used" | awk '{print $NF}' | tr -d '%')
    if [ -n "$USED" ] && [ "$USED" -ge 100 ]; then
        printf "${RED}  [FAIL] Percentage Used: %s%%${NC}\n" "$USED"
        printf "         Disk is fully worn out. Installation not possible.\n"
        FAIL=1
    else
        printf "${GREEN}  [ OK ] Percentage Used: %s%%${NC}\n" "$USED"
    fi

    # --- WARN checks ---

    # 5) Media and Data Integrity Errors
    MEDIA_ERR=$(echo "$SMART_OUT" | grep "Media and Data Integrity Errors" | awk '{print $NF}')
    if [ -n "$MEDIA_ERR" ] && [ "$MEDIA_ERR" -gt 0 ]; then
        printf "${YELLOW}  [WARN] Media and Data Integrity Errors: %s${NC}\n" "$MEDIA_ERR"
        printf "         Data integrity errors have been recorded.\n"
        WARN=1
    else
        printf "${GREEN}  [ OK ] Media and Data Integrity Errors: %s${NC}\n" "$MEDIA_ERR"
    fi

    # 6) Temperature
    TEMP=$(echo "$SMART_OUT" | grep "^Temperature:" | awk '{print $2}')
    if [ -n "$TEMP" ] && [ "$TEMP" -ge 70 ]; then
        printf "${YELLOW}  [WARN] Disk temperature: %s C${NC}\n" "$TEMP"
        printf "         Disk is overheating -- check cooling.\n"
        WARN=1
    else
        printf "${GREEN}  [ OK ] Disk temperature: %s C${NC}\n" "$TEMP"
    fi

    printf "\n"

    # --- Result ---

    if [ "$FAIL" -eq 1 ]; then
        printf "${RED}=================================================${NC}\n"
        printf "${RED}  This disk is not suitable for OS installation.${NC}\n"
        printf "${RED}  Please use a different disk.${NC}\n"
        printf "${RED}=================================================${NC}\n"
        printf "\n"
        exit 1
    fi

    if [ "$WARN" -eq 1 ]; then
        printf "${YELLOW}=================================================${NC}\n"
        printf "${YELLOW}  Disk is usable but warnings were found.${NC}\n"
        printf "${YELLOW}=================================================${NC}\n"
        printf "\n"
        printf "  Continue with installation anyway? [y/N] "
        read ANSWER
        case "$ANSWER" in
            y|Y) printf "\n" ;;
            *)
                printf "  Installation cancelled.\n"
                printf "\n"
                exit 1
                ;;
        esac
    fi

    if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
        printf "${GREEN}=================================================${NC}\n"
        printf "${GREEN}  Disk is healthy. Proceeding with installation.${NC}\n"
        printf "${GREEN}=================================================${NC}\n"
        printf "\n"
    fi

fi

# ¦¦ 3. Unmount existing partitions ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

printf "[ 3/5 ] Unmounting NVMe partitions...\n"

MOUNTED=$(mount | grep "^/dev/nvme0" | awk '{print $1}')
if [ -n "$MOUNTED" ]; then
    for DEV in $MOUNTED; do
        printf "        Unmounting %s...\n" "$DEV"
        umount "$DEV" 2>/dev/null
        if mount | grep -q "^$DEV "; then
            printf "\n"
            printf "${RED}ERROR: Could not unmount %s.${NC}\n" "$DEV"
            printf "       Close any processes using the disk and try again.\n"
            printf "\n"
            exit 1
        fi
    done
    printf "        OK -- all partitions unmounted\n"
else
    printf "        OK -- no partitions mounted\n"
fi
printf "\n"

# ¦¦ 4. Download nvme-img.bin ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

IMG="/tmp/nvme-img.bin"
IMG_URL="https://github.com/woziwrt/bpi-r4-rescue/releases/download/rescue-latest/nvme-img.bin"

printf "[ 4/5 ] Acquiring nvme-img.bin...\n"
printf "\n"
printf "  [1] Download from GitHub\n"
printf "  [2] Load from USB drive\n"
printf "\n"
printf "  Select source [1/2]: "
read SRC

case "$SRC" in

    1)
        printf "\n"
        printf "        Checking network...\n"
        if ! ping -c 1 -W 3 github.com > /dev/null 2>&1; then
            printf "\n"
            printf "${RED}ERROR: No network connectivity (cannot reach github.com).${NC}\n"
            printf "       Check your network connection and try again.\n"
            printf "\n"
            exit 1
        fi
        printf "        OK -- network reachable\n"
        printf "        Downloading nvme-img.bin (~103 MB)...\n"
        printf "\n"
        wget -O "$IMG" "$IMG_URL"
        if [ $? -ne 0 ] || [ ! -s "$IMG" ]; then
            printf "\n"
            printf "${RED}ERROR: Download failed.${NC}\n"
            printf "       Check network connection or use USB fallback.\n"
            printf "\n"
            rm -f "$IMG"
            exit 1
        fi
        printf "\n"
        printf "        OK -- download complete\n"
        ;;

    2)
        printf "\n"
        printf "        Looking for USB drive...\n"
        USB_DEV=$(ls /dev/sd*1 2>/dev/null | head -1)
        if [ -z "$USB_DEV" ]; then
            printf "\n"
            printf "${RED}ERROR: No USB drive found (/dev/sd*1).${NC}\n"
            printf "       Insert USB drive and try again.\n"
            printf "\n"
            exit 1
        fi
        printf "        Found %s -- mounting...\n" "$USB_DEV"
        mkdir -p /mnt/usb
        mount "$USB_DEV" /mnt/usb 2>/dev/null
        if [ $? -ne 0 ]; then
            printf "\n"
            printf "${RED}ERROR: Could not mount %s.${NC}\n" "$USB_DEV"
            printf "\n"
            exit 1
        fi
        if [ ! -f "/mnt/usb/nvme-img.bin" ]; then
            printf "\n"
            printf "${RED}ERROR: nvme-img.bin not found on USB drive.${NC}\n"
            printf "       Copy nvme-img.bin to the root of the USB drive.\n"
            printf "\n"
            umount /mnt/usb
            exit 1
        fi
        printf "        Copying nvme-img.bin from USB...\n"
        cp /mnt/usb/nvme-img.bin "$IMG"
        umount /mnt/usb
        printf "        OK -- file ready\n"
        ;;

    *)
        printf "\n"
        printf "${RED}ERROR: Invalid selection.${NC}\n"
        printf "\n"
        exit 1
        ;;
esac

printf "\n"

# ¦¦ 5. Write image to disk ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

printf "[ 5/5 ] Writing image to %s...\n" "$NVME_DEV"
printf "\n"
printf "${RED}  WARNING: This will ERASE ALL DATA on %s.${NC}\n" "$NVME_DEV"
printf "\n"
printf "  Are you sure? Type YES to confirm: "
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    printf "\n"
    printf "  Installation cancelled.\n"
    printf "\n"
    rm -f "$IMG"
    exit 1
fi

printf "\n"
printf "        Writing... (do not power off)\n"
printf "\n"

dd if="$IMG" of="$NVME_DEV" bs=1M conv=fsync status=progress

if [ $? -ne 0 ]; then
    printf "\n"
    printf "${RED}ERROR: dd failed. Disk may be in inconsistent state.${NC}\n"
    printf "\n"
    rm -f "$IMG"
    exit 1
fi

printf "\n"
printf "        Syncing...\n"
sync

rm -f "$IMG"
printf "        Cleanup done\n"
printf "\n"

printf "${GREEN}=================================================${NC}\n"
printf "${GREEN}  Installation complete!${NC}\n"
printf "${GREEN}=================================================${NC}\n"
printf "\n"
printf "  Next step: set DIP switches SW3-A=1, SW3-B=1\n"
printf "             then reboot into NVMe.\n"
printf "\n"
