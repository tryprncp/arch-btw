#!/bin/bash

set -e

# Ask the user for Arch Linux installation type
echo -e "\nChoose Arch Linux installation type:"
read -p "1) Minimal install, 2) With HyDE, 3) With i3WM (default is 1): " TYPE
echo
TYPE="${TYPE:-1}"

# Validate the user input
if [ "$TYPE" != "1" ] && [ "$TYPE" != "2" ] && [ "$TYPE" != "3" ]; then
    echo "Invalid input. Please input the number of your choice."
    exit 1
fi

# Set hostname
read -p "Set hostname: " HOSTNAME
echo

# Set root password
read -p "Set root password: " ROOT_PASSWORD
echo

# Set username and password
read -p "Set username: " USERNAME
read -p "Set password for $USERNAME: " USER_PASSWORD
echo

# Set disk name
read -p "Enter disk name: " DISK

# Set timezone
timedatectl set-timezone Asia/Manila

# Initialize pacman-key
pacman-key --init
pacman-key --populate archlinux

# Install reflector and setup mirrorlist
pacman -Syy
pacman -S --noconfirm reflector
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -c "SG" -f 10 -l 10 -n 10 --save /etc/pacman.d/mirrorlist

# Set variable based on disk name
if [[ $DISK == nvme* ]]; then
    PART="${DISK}p"
else
    PART="${DISK}"
fi

# Create partitions and format partitions
if [ ! -e /dev/${PART}1 ]; then
    parted /dev/$DISK --script mklabel gpt
    parted /dev/$DISK --script mkpart primary fat32 1MiB 500MiB
    parted /dev/$DISK --script set 1 esp on
    parted /dev/$DISK --script mkpart primary ext4 500MiB 100%
    # Format partition 1 to fat32 filesystem
    mkfs.fat -F 32 /dev/${PART}1
    # Format partition 2 to ext4 filesystem
    mkfs.ext4 /dev/${PART}2
    # Mount partition 2
    mount /dev/${PART}2 /mnt
fi

# Install essential packages using pacstrap
pacstrap /mnt base base-devel linux linux-firmware sof-firmware intel-ucode grub efibootmgr sudo networkmanager git neovim man-db --needed

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Create a post-install script to be performed by arch-chroot
cat <<EOF_CHROOT > /mnt/root/chroot_script.sh
#!/bin/bash
set -e

# Set timezone
timedatectl set-timezone Asia/Manila
timedatectl set-ntp true

# Set locale and language
sed -i 's/#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_PH.UTF-8 > /etc/locale.conf
export LANG=en_PH.UTF-8

# Setup hostname
echo $HOSTNAME > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1  localhost
::1  localhost
127.0.0.1  $HOSTNAME
HOSTS

# Mount partition 1 and install grub into it
mount --mkdir /dev/${PART}1 /boot/efi
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Setup root and user credentials
echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | passwd
useradd -m $USERNAME
echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USERNAME
usermod -aG wheel,audio,video,storage $USERNAME
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME

# Ignore power button
sed -i '/^#HandlePowerKey=ignore/s/^#//' /etc/systemd/logind.conf

# Enable network manager
systemctl enable NetworkManager
EOF_CHROOT

# Append additional commands to chroot_script.sh to clone and install HyDE if the user input is 2
if [ "$TYPE" == "2" ]; then
    echo "su - $USERNAME" >> /root/chroot_script.sh
    echo "git clone --depth 1 https://github.com/tryprncp/hyprdots HyDE && ./HyDE/Scripts/install.sh" >> /root/chroot_script.sh
fi

# Append additional commands to chroot_script.sh to clone and install i3WM if the user input is 3
if [ "$TYPE" == "3" ]; then
    echo "su - $USERNAME" >> /root/chroot_script.sh
    echo "git clone --depth 1 https://github.com/tryprncp/i3WM && ./i3WM/Scripts/install.sh" >> /root/chroot_script.sh
fi

# Execute the script using arch-chroot and remove it afterwards
arch-chroot /mnt /bin/bash /root/chroot_script.sh
rm /mnt/root/chroot_script.sh

# Unmount filesystem
umount -l /mnt

# Execute shutdown if everything is successful
if [ $? -eq 0 ]; then
    shutdown now
else
    exit 2
fi
