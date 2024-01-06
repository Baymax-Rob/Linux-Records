#! /bin/bash

const_1G=1024*1024*1024

# image file size
image_size=$((1*$const_1G))

# output file name
# image_name="evcc_emmc_image.img"
image_name="evcc_sd_emmc_test_image.img"

# fat part size, MB
fat_size=100

# delete old img
if [ -f "./${image_name}" ];then
	rm ./${image_name}
fi

# create 4G NULL image file
dd if=/dev/zero of=$image_name  bs=1 seek=$image_size count=0

# fdisk create two partitions: FAT, ext4
cat << EOT | fdisk $image_name
n
p
1

+$((fat_size))M
n
p
2


t
1
c
t
2
83
a
1
w
EOT

# Image file association to a circular device 0 or 1
LOOP_DEV=12
losetup /dev/loop${LOOP_DEV} $image_name

if [ $? -ne 0 ] ; then

	LOOP_DEV=13
	losetup /dev/loop${LOOP_DEV} $image_name
	if [ $? -ne 0 ] ; then
		echo "error: could not add loopback device /dev/loop0 and /dev/loop1"
		exit -1
	fi
fi

# Use kpartx to add a partition map that makes the partition operable
kpartx -av /dev/loop${LOOP_DEV}
if [ $? -ne 0 ] ; then
	echo "error:kpartx"
	exit -1
fi

# wait for ready
sleep 5

# Check if the first partition exists, if not clean and exit.
if [ ! -e "/dev/mapper/loop${LOOP_DEV}p1" ];then
	echo "no /dev/mapper/loop${LOOP_DEV}p1 found"
	kpartx -d /dev/loop${LOOP_DEV}
	losetup -d /dev/loop${LOOP_DEV}
	exit -1
fi

# Create FAT and ext4 filesystems on two separate partitions
mkfs.vfat /dev/mapper/loop${LOOP_DEV}p1
mkfs.ext4 /dev/mapper/loop${LOOP_DEV}p2

# Create two directories for mounting FAT, ext4 partitions
mkdir -p /mnt/fat_part
mkdir -p /mnt/ext4_part

# Force flush the file system buffer, mount both partitions.
sync
mount /dev/mapper/loop${LOOP_DEV}p1 /mnt/fat_part
mount /dev/mapper/loop${LOOP_DEV}p2 /mnt/ext4_part

# Outputs a prompt and copies the files needed for FAT, ext4 partitions to the mount point.
echo "copying fat files to fat part..."
cp -f ./fat_files/* /mnt/fat_part

echo "copying rootfs to ext4 part..."
# cp -rf ./ext4_files/* /mnt/ext4_part
tar xzf ./ext4_files/debian11-test-RootFs.tar -C /mnt/ext4_part
#tar xzf ./ext4_files/debian11-evcc-rootfs.tar -C /mnt/ext4_part
# tar xzf ./ext4_files/debian11-evcc-rootfs.tar.gz -C /mnt/ext4_part

# Force flush the file system buffer again and unmount both partitions.
sync
umount /mnt/fat_part
umount /mnt/ext4_part

# Delete the mount point directory.
rm -r /mnt/fat_part
rm -r /mnt/ext4_part

# Remove the partition mapping and unlink the image file from the loop device.
kpartx -d /dev/loop${LOOP_DEV}
losetup -d /dev/loop${LOOP_DEV}

echo "Finished copying"