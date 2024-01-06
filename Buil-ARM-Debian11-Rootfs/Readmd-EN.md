# Building the ARM Debian root file system

It is usually divided into several main steps. Below is a detailed tutorial step-by-step to help you build a Debian root filesystem for ARM devices on an x86_64 machine using `debootstrap` and `qemu-user-static`.

### Step 1: Install necessary packages

On your Debian or Ubuntu system, open a terminal and install the following packages:

```sh
sudo apt-get update
sudo apt-get install debootstrap qemu-user-static binfmt-support
```

### Step 2: Create the base file system

Choose a directory as the location of the root file system and use `debootstrap` to create the base system. Assume you want to build a `bullseye` version of Debian for the `armhf` architecture, and the target root file system is located at `/path/to/rootfs`：

```sh
sudo debootstrap --arch=armhf --foreign 
bullseye rootfs https://mirrors.tuna.tsinghua.edu.cn/debian/
```

### Step 3: Prepare the environment for chroot

Copy `qemu-arm-static` to the newly created root filesystem to emulate the ARM instruction set in a chroot environment:

```sh
sudo cp /usr/bin/qemu-arm-static rootfs/usr/bin/
```

### Step 4: Complete the second stage of debootstrap

Now, use chroot to switch to the new root filesystem and complete the second phase of `debootstrap`:

```sh
sudo DEBIAN_FRONTEND=noninteractive 
DEBCONF_NONINTERACTIVE_SEEN=true chroot rootfs 

debootstrap/debootstrap --second-stage
```

### Step 5: Execute the mount script

```bash
nano mount.sh
#!/bin/bash
mnt() {
	echo "MOUNTING"
	sudo mount -t proc /proc ${2}proc
	sudo mount -t sysfs /sys ${2}sys
	sudo mount -o bind /dev ${2}dev
	sudo mount -o bind /dev/pts ${2}dev/pts
	sudo chroot ${2}
}
umnt() {
	echo "UNMOUNTING"
	sudo umount ${2}proc
	sudo umount ${2}sys
	sudo umount ${2}dev/pts
	sudo umount ${2}dev
}

if [ "$1" == "-m" ] && [ -n "$2" ] ;
then
	mnt $1 $2
elif [ "$1" == "-u" ] && [ -n "$2" ];
then
	umnt $1 $2
else
	echo ""
	echo "Either 1'st, 2'nd or both parameters were missing"
	echo ""
	echo "1'st parameter can be one of these: -m(mount) OR -u(umount)"
	echo "2'nd parameter is the full path of rootfs directory(with trailing '/')"
	echo ""
	echo "For example: ch-mount -m /media/sdcard/"
	echo ""
	echo 1st parameter : ${1}
	echo 2nd parameter : ${2}
fi

source mount.sh -m ./rootfs/
```


### Step 6: Configure basic system settings

In a chroot environment, some basic configuration can be done

```sh
#编辑
sudo nano /etc/apt/sources.list

#换成如下内容:

# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free

# Set time zone
echo "Asia/Shanghai" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# 配置locales
echo "proc /proc proc defaults 0 0" >> etc/fstab 
export LC_ALL=C

# Set up network (if needed)
echo "allow-hotplug eth0" > /etc/network/interfaces.d/eth0
echo "iface eth0 inet dhcp" >> /etc/network/interfaces.d/eth0

# Set hostname
echo "baymax" > /etc/hostname
passwd root

exit
```



### Step 6: Install necessary packages

Install other packages you need in a chroot environment

```sh

sudo chroot rootfs


apt-get update
apt install sudo
apt install net-tools
apt install ethtool
apt install gcc
apt install python3
...


exit
```

### Step 7: Clean and Exit

After all configuration is complete, exit the chroot environment and clean up files no longer needed:

```sh
sudo rm /rootfs/usr/bin/qemu-arm-static
```

Unmount

```
source mount.sh -u ./rootfs/
```


### Step 8: Packaging file system

```bash
sudo tar -zcvf debian11-evcc-rootfs.tar.gz ./rootfs/*
```

### 注意事项：

- Requires appropriate adjustments based on your needs and target hardware.
- `/path/to/rootfs` is the path where you wish to create the new root file system.
- `/path/to/arm-rootfs.img` is the path to the root file system image file you wish to create.
- The above steps may need to be adjusted appropriately in different environments.
- If you are using this root filesystem on real ARM hardware, you may also need to install the bootloader and kernel.

