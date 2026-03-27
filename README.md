# OpenWrt build + deploy for Banana Pi BPI-R4 (kernel 6.12)

This repository builds OpenWrt 25.12 for Banana Pi BPI-R4 (MT7988, Wi-Fi 7) using the MediaTek SDK and includes a **deploy system** that lets you install OpenWrt directly to eMMC — no Linux machine needed, everything runs on GitHub.

**You do not need a local build machine.** Trigger the build on GitHub and download ready-to-use images.

---

> ⚠️ **DO NOT FORK THIS REPOSITORY**
>
> Forking will break the eMMC deploy system. The rescue image contains hardcoded URLs pointing to this repository. If you fork, the `install-emmc.sh` script will always download images from the original repository, not from your fork.

---

## What this repository offers

- **SD card image** — standard OpenWrt image, flash with Etcher and boot directly from SD card.
- **eMMC deploy** — install OpenWrt permanently to the internal eMMC storage using a guided rescue system. SD card is only used temporarily during installation.
- **NVMe deploy** — planned for a future release.

---

## Quick start — SD card

1. Open the **Actions** tab in this repository.
2. Select the workflow **Build BPI-R4**.
3. Click **Run workflow**, set **Target media** to `sd`, leave everything else as default, and confirm.
4. After the workflow finishes (approx. 2 hours), open the **Releases** tab.
5. Download `openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz`.
6. Flash it to your SD card using [Balena Etcher](https://etcher.balena.io/).
7. Insert the SD card into BPI-R4, set DIP switches **SW3-A=0, SW3-B=0**, and power on.

---

## Quick start — eMMC install

This installs OpenWrt permanently to the internal eMMC storage. The SD card is only used during installation and can be reused afterward.

### What you need
- A microSD card (any size, 1 GB is enough).
- A network cable connected to BPI-R4 during installation (for downloading the eMMC image).

### DIP switch reference

| Boot medium | SW3-A | SW3-B |
|-------------|-------|-------|
| SD card     | 0     | 0     |
| NAND rescue | 0     | 1     |
| eMMC        | 1     | 0     |

### Step 1 — Build the eMMC release

1. Open the **Actions** tab in this repository.
2. Select the workflow **Build BPI-R4**.
3. Click **Run workflow**, set **Target media** to `emmc`, leave everything else as default, and confirm.
4. After the workflow finishes (approx. 2 hours), open the **Releases** tab.
5. Download `bpi-r4-rescue-sdcard.img.gz`.

### Step 2 — Flash the rescue SD card

1. Flash `bpi-r4-rescue-sdcard.img.gz` to your SD card using [Balena Etcher](https://etcher.balena.io/).
2. Insert the SD card into BPI-R4.
3. Set DIP switches **SW3-A=0, SW3-B=0** (SD boot).
4. Power on and wait for BPI-R4 to boot.

### Step 3 — Install NAND rescue system

1. Connect to BPI-R4 via SSH: `ssh root@192.168.1.1` (no password by default).
2. Run:
   ```
   /root/bpi-r4-install/install-nand.sh
   ```
3. Wait for the script to finish — it will flash the rescue system to NAND.
4. Power off BPI-R4.
5. Set DIP switches **SW3-A=0, SW3-B=1** (NAND boot).
6. Power on and wait for BPI-R4 to boot into the NAND rescue system.

### Step 4 — Install OpenWrt to eMMC

1. Connect to BPI-R4 via SSH again: `ssh root@192.168.1.1`
2. Make sure a network cable is connected (the script downloads the eMMC image from GitHub).
3. Run:
   ```
   /root/bpi-r4-install/install-emmc.sh
   ```
4. The script will download the OpenWrt eMMC image (~103 MB) and flash it to eMMC automatically.
5. Wait for the script to finish.
6. Power off BPI-R4.
7. Set DIP switches **SW3-A=1, SW3-B=0** (eMMC boot).
8. Power on — BPI-R4 will now boot OpenWrt from eMMC.

The SD card is no longer needed. You can reuse it for anything else.

---

## Local build (optional, advanced)

If you prefer to build locally on Linux:

**Requirements (Ubuntu 22.04):**
- Around 120 GB free disk space.
- Basic build tools:
  ```
  sudo apt-get update
  sudo apt-get install -y \
    build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext libncurses-dev libssl-dev python3-distutils python3-setuptools \
    rsync swig unzip zlib1g-dev file wget libelf-dev ccache git
  ```

**Clone and build:**
```
git clone https://github.com/woziwrt/bpi-r4-deploy.git
cd bpi-r4-deploy
chmod +x ./bpi-r4-openwrt-builder.sh
./bpi-r4-openwrt-builder.sh
```

After the script finishes, images are in:
```
openwrt/bin/targets/mediatek/filogic/
```

---

## Repository contents

- `bpi-r4-openwrt-builder.sh` — main build script (clones OpenWrt + MTK SDK, prepares, builds, applies config).
- `configs/config.hnat.la` — default build config (MTK HNAT enabled).
- `rescue/bpi-r4-rescue-sdcard.img.gz` — static rescue SD card image used for eMMC installation.
- `my_files/` — patches, custom packages, LuCI applications.
- `.github/workflows/build.yml` — GitHub Actions workflow.

---

## Notes

- This build is for Banana Pi BPI-R4 only.
- OpenWrt and MTK SDK commits are pinned; updating them requires manual editing of the build script.

### Notes about GitHub runners

This workflow runs on GitHub-hosted runners where free disk space is not guaranteed. If a build fails with a disk-related error, simply re-run the workflow later — runners with sufficient space (~100 GB free) are usually available within a short time.

External mirrors used during the build can also be temporarily slow or unavailable. Re-running the workflow later usually resolves such issues.

