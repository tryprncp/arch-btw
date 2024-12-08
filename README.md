## Arch Linux installation script cuz I'm too lazy to read the archwiki again

After booting to Arch Linux installation media and connecting to the internet, execute the following commands:
```shell
curl -O https://raw.githubusercontent.com/tryprncp/arch-btw/main/arch-btw.sh
chmod +x arch-btw.sh
```
### Command tree
```shell
/usr/bin/bash
├── set -e
└── Variable Declarations
│   ├── HOSTNAME=""
│   ├── ROOT_PASSWORD=""
│   ├── USERNAME=""
│   ├── USER_PASSWORD=""
│   └── DISK=""
└── if [[ $DISK == nvme* ]]; then
│   └── PART=${DISK}p
│   └── PART=${DISK}
└── for PART_NUM in $(parted /dev/$DISK --script print | awk '/^ / {print $1}'); do
│   └── parted /dev/$DISK --script rm $PART_NUM
├── parted /dev/$DISK --script mklabel gpt
├── parted /dev/$DISK --script mkpart primary fat32 1MiB 500MiB
├── parted /dev/$DISK --script set 1 esp on
├── parted /dev/$DISK --script mkpart primary ext4 500MiB 1500MiB
├── parted /dev/$DISK --script mkpart primary luks 1500MiB 100%
├── mkfs.fat -F 32 /dev/${PART}1
├── mkfs.ext4 /dev/${PART}2
├── echo $PASSPHRASE | cryptsetup -v -q -s 512 -h sha512 luksFormat /dev/${PART}3
├── echo $PASSPHRASE | cryptsetup luksOpen /dev/${PART}3 disknuts
├── pvcreate /dev/mapper/disknuts
├── vgcreate arch /dev/mapper/disknuts
├── lvcreate --size 32g arch --name swap
├── lvcreate -l 100%FREE arch --name root
├── vgreduce --size -256M arch/root
├── mkswap /dev/arch/swap
├── mkfs.ext4 /dev/arch/root
├── mount /dev/arch/root /mnt
├── mount --mkdir /dev/${PART}2 /mnt/boot
├── mount --mkdir /dev/${PART}1 /mnt/boot/efi
├── swapon /dev/arch/swap
├── pacman-key --init
├── pacman-key --populate archlinux
├── reflector -c SG -f 10 -l 10 --save /etc/pacman.d/mirrorlist
├── pacstrap -K /mnt base intel-ucode linux linux-firmware sof-firmware
├── genfstab -U /mnt > /mnt/etc/fstab
└── cat << MEOW > /root/chroot_script.sh
│   ├── set -e
│   ├── pacman -S --needed --noconfirm base-devel efibootmgr git grub lvm2 man-db neovim networkmanager sudo zsh
│   ├── ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
│   ├── sed -i 's/#NTP=/NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org/' /etc/systemd/timesyncd.conf
│   ├── hwclock --systohc
│   ├── systemctl enable systemd-timesyncd
│   ├── systemctl start systemd-timesyncd
│   ├── sed -i 's/#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
│   ├── locale-gen
│   ├── echo LANG=en_PH.UTF-8 > /etc/locale.conf
│   ├── echo $HOSTNAME > /etc/hostname
│   ├── cat << PURR > /etc/hosts
│   │   ├── 127.0.0.1 localhost
│   │   ├── ::1 localhost
│   │   └── 127.0.0.1 $HOSTNAME
│   ├── grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
│   ├── UUID=$(blkid -s UUID -o value /dev/${PART}3)
│   ├── sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/quiet/quiet root=\/dev\/mapper\/arch-root cryptdevice=UUID=$UUID:disknuts/' /etc/default/grub
│   ├── grub-mkconfig -o /boot/grub/grub.cfg
│   ├── mkdir /secure
│   ├── dd if=/dev/random of=/secure/root_keyfile.bin bs=512 count=2
│   ├── cryptsetup luksAddKey /dev/${PART}3 /secure/root_keyfile.bin
│   ├── sed -i '/^HOOKS=/ s/block /block encrypt lvm2 /' /etc/mkinitcpio.conf
│   ├── sed -i '/^FILES=/ s/()/(\/secure\/root_keyfile.bin)/' /etc/mkinitcpio.conf
│   ├── echo "root:$ROOT_PASSWORD" | chpasswd
│   ├── useradd -m -G audio,video,storage -s $(which zsh) $USERNAME
│   ├── echo "$USERNAME:$USER_PASSWORD" | chpasswd
│   ├── echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME
│   └── systemctl enable NetworkManager
└── arch-chroot /mnt /bin/bash /root/chroot_script.sh
│   ├── chroot environment
│   ├── pacman -S --needed --noconfirm base-devel efibootmgr git grub lvm2 man-db neovim networkmanager sudo zsh
│   ├── ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
│   ├── sed -i 's/#NTP=/NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org/' /etc/systemd/timesyncd.conf
│   ├── hwclock --systohc
│   ├── systemctl enable systemd-timesyncd
│   ├── systemctl start systemd-timesyncd
│   ├── sed -i 's/#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
│   ├── locale-gen
│   ├── echo LANG=en_PH.UTF-8 > /etc/locale.conf
│   ├── echo $HOSTNAME > /etc/hostname
│   └── cat << PURR > /etc/hosts
│   │   ├── 127.0.0.1 localhost
│   │   ├── ::1 localhost
│   │   └── 127.0.0.1 $HOSTNAME
│   ├── grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
│   ├── UUID=$(blkid -s UUID -o value /dev/${PART}3)
│   ├── sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/quiet/quiet root=\/dev\/mapper\/arch-root cryptdevice=UUID=$UUID:disknuts/' /etc/default/grub
│   ├── grub-mkconfig -o /boot/grub/grub.cfg
│   ├── mkdir /secure
│   ├── dd if=/dev/random of=/secure/root_keyfile.bin bs=512 count=2
│   ├── cryptsetup luksAddKey /dev/${PART}3 /secure/root_keyfile.bin
│   ├── sed -i '/^HOOKS=/ s/block /block encrypt lvm2 /' /etc/mkinitcpio.conf
│   ├── sed -i '/^FILES=/ s/()/(\/secure\/root_keyfile.bin)/' /etc/mkinitcpio.conf
│   ├── echo "root:$ROOT_PASSWORD" | chpasswd
│   ├── useradd -m -G audio,video,storage -s $(which zsh) $USERNAME
│   ├── echo "$USERNAME:$USER_PASSWORD" | chpasswd
│   ├── echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME
│   └── systemctl enable NetworkManager
├── rm /mnt/root/chroot_script.sh
├── swapoff -a
├── umount -l /mnt
└── if [ $? -eq 0 ]; then
│   ├── echo -e "\033[0;32m\n[I use Arch, btw]\033[0m"
│   ├── sleep 3
│   └── systemctl reboot
└── exit 2
```
