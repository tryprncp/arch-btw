## Installation script for minimal Arch Linux installation

After booting into the Arch Linux installation media, download this script using the following command: 

```shell
wget https://raw.githubusercontent.com/tryprncp/arch-btw/main/arch-btw.sh
```

Make the script executable and run it using the following commands:

```shell
chmod +x arch-btw.sh
./arch-btw.sh
```

> [!TIP]
> Identify your disk name using `fdisk -l` or `lsblk`
>
> These are the packages that will be installed by `pacstrap`:
> `base base-devel linux linux-firmware sof-firmware intel-ucode grub efibootmgr sudo networkmanager git neovim man-db`
