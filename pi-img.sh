#!/bin/bash

print_usage() {
	echo USAGE: $0 RASPBIAN_IMAGE SSH_PUBKEY
	echo
	echo -e "RASPBIAN_IMAGE \t is the .img file downloaded for raspbian from https://raspberrypi.org/downloads/raspbian."
	echo -e "SSH_PUBKEY \t is the ssh public key to be added to pi's authorized_keys file"
	echo
	exit 1
}

check_readable() {
	if [[ ! -f $1 ]] || [[ ! -r $1 ]]
	then
		print_usage
	fi
}

check_kpartx() {
	if [ -x /sbin/kpartx ]
	then
		return
	fi

	echo "It looks like kpartx is not yet installed. Installing now."
	sudo apt-get -y install kpartx
}

check_qemu() {
	if [ -x /usr/bin/qemu-arm-static ]
	then
		return
	fi

	echo "It looks like qemu-arm-static is not installed. Installing now"
	sudo apt-get -y install qemu-user-static
}

check_binfmts() {
	if [ -e /proc/sys/fs/binfmt_misc/qemu-arm ]
	then
		return
	fi

	echo "It looks like binfmts isn't set up right. Fixing"
	update-binfmts --importdir /var/lib/binfmts/ --import 2>&1 > /dev/null
}

# Entry point
if [ $# -ne 2 ]
then
	print_usage
fi

check_readable $1
check_readable $2

check_kpartx
check_qemu
check_binfmts

# mount partition from pi image
sudo kpartx -asp pi-ssh-enable $1
export ROOT=$(find /dev/mapper -name "loop*pi-ssh-enable2")
mkdir -p /tmp/pi-ssh-enable
sudo mount -o rw $ROOT /tmp/pi-ssh-enable

# authorized_keys file
export DIR=$(pwd)
cd /tmp/pi-ssh-enable/home/pi
export OLD_UMASK=$(umask)
umask 0077
sudo mkdir -p .ssh
cd $DIR
cat $2 | sudo tee /tmp/pi-ssh-enable/home/pi/.ssh/authorized_keys > /dev/null
cd /tmp/pi-ssh-enable/home/pi
umask $OLD_UMASK
cd $DIR

# enable ssh daemon
sudo cp $(which qemu-arm-static) /tmp/pi-ssh-enable/usr/bin/
sudo chroot /tmp/pi-ssh-enable systemctl enable ssh

# change pi's password
echo -e "\n Changing pi's password"
sudo chroot /tmp/pi-ssh-enable passwd pi

sudo chroot /tmp/pi-ssh-enable chown -R pi:pi /home/pi/.ssh
sudo rm /tmp/pi-ssh-enable/usr/bin/qemu-arm-static

# unmount
sudo umount /tmp/pi-ssh-enable
sudo kpartx -d $1

echo "Done"

