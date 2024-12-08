#!/usr/bin/env bash

script installation.log
set -e

# Set hostname
HOSTNAME=""

# Set root password
ROOT_PASSWORD=""

# Set username and password
USERNAME=""
USER_PASSWORD=""

# Set disk name (run lsblk to identify your disk)
DISK=""

# Set disk encryption passphrase
PASSPHRASE=""

if [[ $DISK == nvme* ]]; then
    PART=${DISK}p
else
    PART=${DISK}
fi

echo -e "\033[0;32m\n[Removing the existing partitions]\033[0m"
for PART_NUM in $(parted /dev/$DISK --script print | awk '/^ / {print $1}'); do
    parted /dev/$DISK --script rm $PART_NUM
done

echo -e "\033[0;32m\n[Creating new partitions]\033[0m"
parted /dev/$DISK --script mklabel gpt
parted /dev/$DISK --script mkpart primary fat32 1MiB 500MiB
parted /dev/$DISK --script set 1 esp on
parted /dev/$DISK --script mkpart primary ext4 500MiB 1500MiB
parted /dev/$DISK --script mkpart primary luks 1500MiB 100%

echo -e "\033[0;32m\n[Formatting efi partition]\033[0m"
mkfs.fat -F 32 /dev/${PART}1
echo -e "\033[0;32m\n[Formatting boot partition]\033[0m"
mkfs.ext4 /dev/${PART}2

echo -e "\033[0;32m\n[Setting up encrypted partition]\033[0m"
echo $PASSPHRASE | cryptsetup -v -q -s 512 -h sha512 luksFormat /dev/${PART}3
echo $PASSPHRASE | cryptsetup luksOpen /dev/${PART}3 disknuts

echo -e "\033[0;32m\n[Creating LVM partitions]\033[0m"
pvcreate /dev/mapper/disknuts
vgcreate arch /dev/mapper/disknuts
lvcreate --size 32g arch --name swap
lvcreate -l 100%FREE arch --name root
vgreduce --size -256M arch/root

echo -e "\033[0;32m\n[Formatting LVM partitions]\033[0m"
mkswap /dev/arch/swap
mkfs.ext4 /dev/arch/root

echo -e "\033[0;32m\n[Mounting the filesystems]\033[0m"
mount /dev/arch/root /mnt
mount --mkdir /dev/${PART}2 /mnt/boot
mount --mkdir /dev/${PART}1 /mnt/boot/efi
swapon /dev/arch/swap

echo -e "\033[0;32m\n[Initializing pacman-key]\033[0m"
pacman-key --init
pacman-key --populate archlinux

echo -e "\033[0;32m\n[Setting up mirrorlist]\033[0m"
reflector -c SG -f 10 -l 10 --save /etc/pacman.d/mirrorlist

echo -e "\033[0;32m\n[Installing the base system]\033[0m"
for i in {1..5}; do
    pacstrap -K /mnt base intel-ucode linux linux-firmware sof-firmware && break
done

echo -e "\033[0;32m\n[Generating filesystem table]\033[0m"
genfstab -U /mnt > /mnt/etc/fstab

echo -e "\033[0;32m\n[Creating a chroot script]\033[0m"
cat << MEOW > chroot_script.sh
set -e

echo -e "\033[0;32m\n[Installing essential packages]\033[0m"
for i in {1..5}; do
    pacman -S --needed --noconfirm base-devel efibootmgr git grub lvm2 man-db neovim networkmanager sudo zsh && break
done

echo -e "\033[0;32m\n[Setting up timezone]\033[0m"
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
sed -i 's/#NTP=/NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org/' /etc/systemd/timesyncd.conf
hwclock --systohc
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

echo -e "\033[0;32m\n[Setting up language and locale]\033[0m"
sed -i 's/#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_PH.UTF-8 > /etc/locale.conf

echo -e "\033[0;32m\n[Setting up hostname]\033[0m"
echo $HOSTNAME > /etc/hostname
cat << PURR > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.0.1   $HOSTNAME
PURR

echo -e "\033[0;32m\n[Installing grub on partition 1]\033[0m"
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
UUID=$(blkid -s UUID -o value /dev/${PART}3)
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/quiet/quiet root=\/dev\/mapper\/arch-root cryptdevice=UUID=$UUID:disknuts/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\033[0;32m\n[Configuring system to unlock the partition with a keyfile]\033[0m"
mkdir /secure
dd if=/dev/random of=/secure/root_keyfile.bin bs=512 count=2
cryptsetup luksAddKey /dev/${PART}3 /secure/root_keyfile.bin
sed -i '/^HOOKS=/ s/block /block encrypt lvm2 /' /etc/mkinitcpio.conf
sed -i '/^FILES=/ s/()/(\/secure\/root_keyfile.bin)/' /etc/mkinitcpio.conf

echo -e "\033[0;32m\n[Setting up root and user credentials]\033[0m"
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G audio,video,storage -s $(which zsh) $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME

echo -e "\033[0;32m\n[Enable networking]\033[0m"
systemctl enable NetworkManager

echo -e "\033[0;32m\n[Exiting arch-chroot environment]\033[0m"
MEOW

echo -e "\033[0;32m\n[Entering arch-chroot environment]\033[0m"
arch-chroot /mnt /bin/bash /root/chroot_script.sh

echo -e "\033[0;32m\n[Cleaning up]\033[0m"
cp installation.log /mnt/root/installation.log
rm /mnt/root/chroot_script.sh
exit

echo -e "\033[0;32m\n[Unmounting the filesystems]\033[0m"
swapoff -a
umount -l /mnt

if [ $? -eq 0 ]; then
    echo -e "\033[0;32m\n[I use Arch, btw]\033[0m"
    sleep 3
    systemctl reboot
else
    exit 2
fi
