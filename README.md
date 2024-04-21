# Module statuses

No LPC driver, suspend, or hibernate for any module yet. All modules are on the 6.7 (stable, but EOL) branch unless otherwise noted.

- **IMX8MQ**: Display initialized in u-boot, hardware works. Linux kernel held back to the 6.1 (LTS) branch.
- **A311D**: Display initialized after u-boot; generation selection must be done via serial console or by editing `/boot/extlinux/extlinux.conf`.
- **LS1028A**: Boots, but display does not initialize. System can be interacted with via serial console or blindly via keyboard. Work-in-progress. Restricted to the `ls1028a` branch at this time.

**WARNING:** There is no binary cache at the moment for the Linux kernels this flake uses. This flake will build the Linux kernel from source, which can take 12 hours or more on an IMX8MQ. The A311D module is roughly three times faster, in my experience, but 4 hours is still a long time to wait for something to compile.

# Build a bootable NixOS SD image

Requires an aarch64 host and Nix with [flake support](https://www.tweag.io/blog/2020-05-25-flakes/).

Assuming you're building this on the MNT Reform itself, you should first install MNT Reform Debian to an NVMe drive and `apt upgrade`. In theory, it should be possible to build from an SD card and an external SSD, but I have not had success with that configuration in practice. A 12GB swapfile is necessary to build the NixOS SD image, assuming a module with 4GB of RAM. Putting the swapfile on an SD card will destroy it before the build is finished. My attempt with an external SSD, meanwhile, did not destroy the drive, but did fail with a strange error message.

Once booted with the NVMe, set up the swapfile:
```
sudo dd if=/dev/zero of=/swapfile bs=4M count=3072
sudo mkswap /swapfile
sudo chmod 0600 /swapfile
sudo swapon /swapfile
```

Install Nix and configure it to use flakes:
```
sh <(curl -L https://nixos.org/nix/install) --daemon
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Build the SD image in a nix shell:
```
nix-shell -p nixUnstable
# Choose the build command matching the module in your Reform.
# For the IMX8MQ module:
nix build git+https://codeberg.org/lykso/hardware-mnt-reform#imx8mq.sdImage -L
# For the A311D module:
nix build git+https://codeberg.org/lykso/hardware-mnt-reform#a311d.sdImage -L
```

## Flash the resulting image to an SD card
```
bzcat ./result/sd-image/nixos-sd-image-*-aarch64-linux.img.bz2 > /dev/mmcblk1
```

## Boot

This image contains a mutable NixOS installation that will initialize itself on the first boot.

## Install NixOS on the NVMe

<details>
  <summary>Setup wireless connection</summary>

  ```
    sudo -i
    wpa_supplicant -B -i wlp1s0 -c <(wpa_passphrase ${SSID} ${PASSWORD})
  ```
</details>

<details>
  <summary>Use flakes (required)</summary>

  ```
    mkdir -p ~/.config/nix
    echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
    nix-shell -p nixUnstable
  ```
</details>

<details>
  <summary>Enable binary cache (strongly recommended)</summary>

  ```
    nix run nixpkgs#cachix -- use nix-community -m user-nixconf -v
  ```
</details>

Prepare partitions:

The following instructions assume installation to an NVMe. The boot device can be either an SD card or the module's eMMC. Note, though, that [flashing the eMMC on the A311D can soft-brick it](https://community.mnt.re/t/nvme-boot-not-working-with-a311d/1942/12), so sticking with the SD card for that module is recommended. To use an SD card as the boot device, you will likely also need a USB SD card adapter^1.

In the instructions below, $UBOOTDEV is assumed to be the path to your u-boot device, $BOOTDEV is assumed to be the path to the device your boot partition will be on, and $BOOTPART is assumed to be the path to your boot partition. E.g., /dev/mmcblk0boot0, /dev/mmcblk0, and /dev/mmcblk0p1, respectively, for the eMMC on the IMX8MQ. For installations targeting an SD card mounted by USB, $UBOOTDEV and $BOOTDEV should be the same.

If installing to the eMMC on the IMX8MQ, make it writable first:
```
echo 0 > /sys/class/block/mmcblk0boot0/force_ro
```

^1 It may also be possible to use a USB stick for the boot device during the installation process, taking care to modify hardware-configuration.nix to point to the /dev/disk/by-uuid path of your target SD card's boot partition, then boot into the official image, unmount /boot and remove the SD card with the official image, mount your target SD card, and copy over everything from the USB stick. This approach has not yet been tested, though.

* <details>
    <summary>Encrypted root partition (recommended)</summary>

    ```
      parted /dev/nvme0n1 mklabel gpt
      parted /dev/nvme0n1 mkpart NIX ext4 0% 100%
      cryptsetup luksFormat /dev/nvme0n1p1
      cryptsetup open /dev/nvme0n1p1 nix
      mkfs.ext4 /dev/mapper/nix
      mount /dev/mapper/nix /mnt/
    ```
  </details>

* <details>
    <summary>Plain text root partition </summary>

    ```
      parted /dev/nvme0n1 mklabel gpt
      parted /dev/nvme0n1 mkpart NIX ext4 0% 100%
      mkfs.ext4 /dev/nvme0n1p1
      mount /dev/nvme0n1p1 /mnt
    ```
  </details>

```
  parted $BOOTDEV mklabel msdos
  parted $BOOTDEV mkpart primary ext4 4MiB 100%
  parted $BOOTDEV toggle 1 BOOT
  mkfs.ext4 $BOOTPART
  mkdir /mnt/boot

  # Mount the boot partition by UUID if using a USB to SD adapter or similar.
  # Otherwise, just mounting $BOOTPART at /mnt/boot is fine.
  # Whatever device path is given is what will end up in the NixOS configuration generated in the next step.

  # N.B.: The 'sudo' in the subcommand is important. blkid will return UUID of the
  # first partition with a UUID it can find if it can't retrive the UUID of the given
  # partition, which is likely if the command isn't run as root.
  export BOOTUUID=$(sudo blkid -o value --match-tag UUID $BOOTPART)

  # Be safe. Check that $BOOTUUID matches the UUID of the expected device.
  echo "$BOOTUUID"
  blkid $BOOTPART

  mount /dev/disk/by-uuid/$BOOTUUID /mnt/boot
```

Flash bootloader:
```
  # For the IMX8MQ module:
  nix build 'git+https://codeberg.org/lykso/hardware-mnt-reform#imx8mq.reform-uboot' -L --no-write-lock-file
  dd if=result/flash.bin of=$UBOOTDEV bs=1024 seek=33

  # For the A311D module:
  # WARNING: FLASHING TO THE EMMC AT THIS STEP CAN SOFT-BRICK YOUR A311D MODULE.
  # FLASHING TO THE EMMC ON THIS MODULE HAS NOT BEEN TESTED BY THE AUTHORS OF THIS README.
  nix build 'git+https://codeberg.org/lykso/hardware-mnt-reform#a311d.reform-uboot' -L --no-write-lock-file
  dd if=result/flash.bin of=$UBOOTDEV bs=512 seek=1 skip=1
```

Generate basic configuration:
```
nixos-generate-config --root /mnt
```

<details>
  <summary>Configuration (required)</summary>

  Add a flake file at `/mnt/etc/nixos/flake.nix` to import configuration from this repository. Be sure to uncomment the `modules` line corresponding to the module in your Reform:
  ```
    {
      description = "Configuration for MNT Reform";

      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
        reform.url = "git+https://codeberg.org/lykso/hardware-mnt-reform";
      };

      outputs = { self, nixpkgs, reform }: {

        nixosConfigurations.reform = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            # Uncomment the NixOS module matching the module in your Reform.
            # reform.imx8mq.nixosModule # For IMX8MQ
            # reform.a311d.nixosModule # For A311D
            ./configuration.nix
            ({ pkgs, ... }: {
              nix.package = pkgs.nixFlakes;
              programs.sway.enable = true;
            })
          ];
        };

      };
    }
  ```
</details>

Start installation:
```
nixos-install --verbose --impure --flake /mnt/etc/nixos#reform
```

If using the IMX8MQ module, shutdown the machine, and flip the DIP switch on the Nitrogen8M_SOM module (under the heatsink). After this step, MNT Reform will boot from NVMe without an SD card.

# Upgrading

```
nixos-rebuild switch --recreate-lock-file --verbose --impure --flake /etc/nixos#reform
```

For more information see the  [NixOS manual](https://nixos.org/manual/nixos/stable/#sec-installation)

N.B.: The rest of this README has not been tested or updated since the repository was forked.

<details>
  <summary>How to upgrade</summary>

  ```
    nixos-rebuild switch --recreate-lock-file --verbose --impure --flake /etc/nixos#reform

    # in case there is new u-boot
    nix build "git+https://codeberg.org/lykso/hardware-mnt-reform#ubootReformImx8mq"
    echo 0 > /sys/class/block/mmcblk0boot0/force_ro
    dd if=result/flash.bin of=/dev/mmcblk0boot0 bs=1024 seek=33
  ```
</details>

# Firmware

## Keyboard

Flash the stock keyboard firmware (assuming the keyboard is in programming mode):
```
doas nix run "git+https://codeberg.org/lykso/hardware-mnt-reform#reform2-keyboard-fw" -L
```

Override the keyboard layout:
```
let
  hardware-mnt-reform =
    builtins.getFlake "git+https://codeberg.org/lykso/hardware-mnt-reform";
in {
  reform2-keyboard-fw =
    hardware-mnt-reform.packages.aarch64-linux.reform2-keyboard-fw.overrideAttrs
    (_: { patches = [ ./custom-firmware.patch ]; });
}
```

## Motherboard

Build and flash:
```
nix build  "git+https://codeberg.org/lykso/hardware-mnt-reform#reform2-lpc-fw-«your-board-rev»" -L
mount «board-rom» /mnt
dd if=result/firmware.bin of="/mnt/firmware.bin" conv=nocreat,notrunc
umount /mnt
```
