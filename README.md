WARNING: There is no binary cache at the moment for the Linux kernels this flake uses. This flake will build the Linux kernel from source, which can take 12 hours or more on an IMX8MQ. The A311D module is roughly three times faster, in my experience, but 4 hours is still a long time to wait for something to compile.

Also, the A311D module does not show the generation selection menu at the moment, due to u-boot being unable to bring up the screen. To recover from an unbootable configuration with this module, you'll have to either use the serial console or attempt to blindly select a prior generation.

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
* <details>
    <summary>Encrypted (recommended)</summary>

    ```
      parted /dev/nvme0n1 mklabel gpt
      parted /dev/nvme0n1 mkpart NIX ext4 0% 100%
      cryptsetup luksFormat /dev/nvme0n1p1
      cryptsetup open /dev/nvme0n1p1 nix
      mkfs.ext4 /dev/mapper/nix
      mount /dev/mapper/nix /mnt/

      parted /dev/mmcblk0 mklabel gpt
      parted /dev/mmcblk0 mkpart BOOT ext4 0% 100%
      mkfs.ext4 /dev/mmcblk0p1
      mkdir /mnt/boot
      mount /dev/mmcblk0p1 /mnt/boot
    ```
  </details>

* <details>
    <summary>Plain text</summary>

    ```
      parted /dev/nvme0n1 mklabel gpt
      parted /dev/nvme0n1 mkpart NIX ext4 0% 100%
      mkfs.ext4 /dev/nvme0n1
      mount /dev/nvme0n1 /mnt

      parted /dev/mmcblk0 mklabel gpt
      parted /dev/mmcblk0 mkpart BOOT ext4 0% 100%
      mkfs.ext4 /dev/mmcblk0p1
      mount /dev/mmcblk0p1 /mnt/boot
    ```
  </details>

Flash bootloader:
```
  # For the IMX8MQ module:
  nix build 'git+https://codeberg.org/lykso/hardware-mnt-reform#imx8mq.reform-uboot' -L
  # For the A311D module:
  nix build 'git+https://codeberg.org/lykso/hardware-mnt-reform#a311d.reform-uboot' -L

  echo 0 > /sys/class/block/mmcblk0boot0/force_ro
  dd if=result/flash.bin of=/dev/mmcblk0boot0 bs=1024 seek=33
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

For more information see the  [NixOS manual](https://nixos.org/manual/nixos/stable/#sec-installation)

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

<details>
  <summary>Important notes</summary>

  * There may be an issue with the early console with some kernel versions (e.g. I haven't managed to make it work on Linux v5.17.6 at the time of writing this). Just type the password blindly.
  * You can choose the NixOS generation at the boot process with UART.
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
