#!/bin/bash

set -e

# Choose Arch Linux installation type:
# 1) Minimal install, 2) With HyDE, 3) With i3WM
TYPE=""

# Set hostname
HOSTNAME=""

# Set root password
ROOT_PASSWORD=""

# Set username and password
USERNAME=""
USER_PASSWORD=""

# Set disk name (run lsblk to identify your disk)
DISK=""

# Set variable based on disk name
if [[ $DISK == nvme* ]]; then
    PART="${DISK}p"
else
    PART="${DISK}"
fi

echo -e "\033[0;32m\n[Removing the existing partitions]\033[0m"
for PART_NUM in $(parted /dev/"$DISK" --script print | awk '/^ / {print $1}'); do
    parted /dev/"$DISK" --script rm "$PART_NUM"
done

echo -e "\033[0;32m\n[Creating new partitions]\033[0m"
parted /dev/"$DISK" --script mklabel gpt
parted /dev/"$DISK" --script mkpart primary fat32 1MiB 500MiB
parted /dev/"$DISK" --script set 1 esp on
parted /dev/"$DISK" --script mkpart primary ext4 500MiB 100%
echo -e "\033[0;32m\n[Formatting partition 1]\033[0m"
mkfs.fat -F 32 /dev/"${PART}"1
echo -e "\033[0;32m\n[Formatting partition 2]\033[0m"
mkfs.ext4 /dev/"${PART}"2

echo -e "\033[0;32m\n[Mounting the root partition to /mnt]\033[0m"
mount /dev/"${PART}"2 /mnt

echo -e "\033[0;32m\n[Initializing pacman-key]\033[0m"
pacman-key --init
pacman-key --populate archlinux

echo -e "\033[0;32m\n[Setting up mirrorlist]\033[0m"
reflector -c "SG" -f 10 -l 10 -n 10 --save /etc/pacman.d/mirrorlist

echo -e "\033[0;32m\n[Installing the base system]\033[0m"
for i in {1..10}; do pacstrap -K /mnt base base-devel linux linux-firmware sof-firmware intel-ucode && break; done

echo -e "\033[0;32m\n[Generating filesystem table]\033[0m"
genfstab -U /mnt >/mnt/etc/fstab

echo -e "\033[0;32m\n[Creating a chroot script]\033[0m"
cat <<EOF_CHROOT >/mnt/root/chroot_script.sh
#!/bin/bash
set -e

echo -e "\033[0;32m\n[Installing essential packages]\033[0m"
for i in {i..10}; do pacman -S --needed --noconfirm git grub efibootmgr neovim networkmanager man-db sudo && break; done

echo -e "\033[0;32m\n[Setting up timezone]\033[0m"
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

echo -e "\033[0;32m\n[Setting up language and locale]\033[0m"
sed -i 's/#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_PH.UTF-8 > /etc/locale.conf
export LANG=en_PH.UTF-8

echo -e "\033[0;32m\n[Setting up hostname]\033[0m"
echo $HOSTNAME > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1  localhost
::1  localhost
127.0.0.1  $HOSTNAME
HOSTS

echo -e "\033[0;32m\n[Installing grub on partition 1]\033[0m"
mount --mkdir /dev/${PART}1 /boot/efi
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\033[0;32m\n[Setting up root and user credentials]\033[0m"
echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | passwd
useradd -m $USERNAME
echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USERNAME
usermod -aG wheel,audio,video,storage $USERNAME
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME

# Ignore power button
sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf

echo -e "\033[0;32m\n[Enabling services]\033[0m"
systemctl enable NetworkManager
EOF_CHROOT

# Append additional commands to chroot_script.sh to install HyDE if the $TYPE is 2
if [ "$TYPE" == "2" ]; then
    echo -e "\033[0;32m\n[Installing HyDE]\033[0m"
    echo "su - $USERNAME -c '{
        git clone --depth 1 https://github.com/tryprncp/hyprdots HyDE
        ./HyDE/Scripts/install.sh
    }'" >>/mnt/root/chroot_script.sh
fi

# Append additional commands to chroot_script.sh to install i3WM if the $TYPE is 3
if [ "$TYPE" == "3" ]; then
    echo -e "\033[0;32m\n[Installing i3WM]\033[0m"
    echo "su - $USERNAME -c '{
        git clone --depth 1 https://github.com/tryprncp/i3WM
        ./i3WM/Scripts/install.sh
    }'" >>/mnt/root/chroot_script.sh
fi

echo -e "\033[0;32m\n[Entering arch-chroot environment]\033[0m"
arch-chroot /mnt /bin/bash /root/chroot_script.sh
echo -e "\033[0;32m\n[Exiting arch-chroot environment]\033[0m"
echo -e "\033[0;32m\n[Removing chroot script]\033[0m"
rm /mnt/root/chroot_script.sh

echo -e "\033[0;32m\n[Unmounting the root partition]\033[0m"
umount -l /mnt

# Execute shutdown if everything is successful
if [ $? -eq 0 ]; then
    echo -e "\033[0;32m\n[I use Arch, btw]\033[0m"
    shutdown now
else
    exit 2
fi
