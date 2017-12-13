#!/bin/bash

print_usage() {
	echo USAGE: $0 INTERFACE DOT_SSH_TAR
	echo 
	echo "Both arguments are compulsory."
	echo -e "INTERFACE \t is the network interface to set up for communication \n\t\t with edsac status monitor nodes."
	echo -e "DOT_SSH_DIR \t is a tar archive containing ssh keys for the mothership."
	echo
	exit 1
}

install_software() {
	(git && gcc && autoreconf && make && pkg-config) > /dev/null
	local software=$?
	if [ $software -eq 127 ]
	then
		# make and install the mothership software
		echo "Installing software"
		sudo apt-get update
		yes | sudo apt-get install git libtool gcc autoconf libglib2.0-dev make pkg-config libgtk-3-dev libsqlite3-dev xfce4-terminal
	else
		echo "It looks like the required software is already installed"
	fi
}

build() {
	if [ -x /usr/local/bin/mothership_gui ]
	then
		echo "It looks like the mothership software is already built and installed"
		return
	fi

	local dir=edsac-build
	if [ ! -d $dir ]
	then
		install_software
		echo "Building mothership software"
		mkdir $dir
		cd $dir
		git clone https://github.com/edsac-status-monitor/libedsacnetworking.git
		cd libedsacnetworking
		autoreconf -i
		./configure
		make -j4
		make check
		echo "Installing libnetworking"
		sudo make install
		echo "export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
		export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
		cd ..

		git clone https://github.com/edsac-status-monitor/mothership-gui.git
		cd mothership-gui
		autoreconf -i
		./configure
		make -j4
		make check
		echo "Installing mothership-gui"
		sudo make install
		echo "export PATH=/usr/local/bin:$PATH" >> ~/.bashrc
		export PATH=/usr/local/bin:$PATH
		cd ../..
		echo "You will need to source ~/.bashrc (or open a new shell) before mothership_gui is usable"
	else
		rm -rf $dir
		build
	fi
}

install_ssh() {
	if [[ ! -e ~/.ssh/id_ed25519 ]] && [[ ! -e ~/.ssh/id_rsa ]]
	then
		echo "Installing ssh keys"
		local dir=$(pwd)
		cp $1 ~/
		cd ~/
		tar -xvf $(basename $1)
		rm $(basename $1)
		cd $dir
	else
		echo "It looks like ssh keys were already installed."
	fi
}

networking() {
	if [[ ! -e /etc/udhcpd.conf ]] || [[ ! -e /etc/default/udhcpd ]]
	then
		# set the interface in the udhcpd configuration file
		cat udhcpd.conf | sed 's/INTERFACE_CHANGE_ME/'$1'/' > udhcpd.conf.inst
		echo "Installing dhcp configuration files"
		sudo install udhcpd.conf.inst /etc/udhcpd.conf
		sudo install udhcpd /etc/default/
		rm udhcpd.conf.inst

		echo "Configuring network interface"
		#sudo systemctl stop NetworkManager
		#sudo systemctl disable NetworkManager
		echo | sudo tee -a /etc/network/interfaces
		echo auto $1 | sudo tee -a /etc/network/interfaces
		echo iface $1 inet static | sudo tee -a /etc/network/interfaces
		echo address 172.16.0.1 | sudo tee -a /etc/network/interfaces
		echo netmask 255.255.0.0 | sudo tee -a /etc/network/interfaces
		echo network 172.16.0.0 | sudo tee -a /etc/network/interfaces
		echo allow hotplug | sudo tee -a /etc/network/interfaces
		sudo systemctl restart networking
		sudo systemctl restart networking # weirdly we don't seem to get routing right the first time
	else
		echo "It looks like the network was alredy configured"
	fi

	if [ ! -x /usr/sbin/udhcpd ]
	then
		echo "Installing udhcpd"
		echo -e "N\nN" | sudo apt-get --assume-no install udhcpd
		sudo mkdir -p /var/lib/misc/
		sudo systemctl enable udhcpd
		sudo systemctl start udhcpd
	else
		echo "It looks like udhcpd was already installed"
	fi
}

# Entry Point:

# number of arguments
if [ $# -ne 2 ] 
then
	print_usage
fi

# DOT_SSH_TAR exists and is a readable file
if [[ ! -f $2 ]] || [[ ! -r $2 ]]
then
	print_usage
fi

build
install_ssh $2
networking $1

