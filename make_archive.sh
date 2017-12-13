#!/bin/bash

set -e

# libedsacnetworking
if [ ! -x /usr/bin/git ]
then
    yes | sudo apt install git gcc autoconf libglib2.0-dev libtool make pkg-config
fi

if [ ! -e libedsacnetworking ] 
then
    git clone https://github.com/edsac-status-monitor/libedsacnetworking.git
fi

cd libedsacnetworking
export CFLAGS=-Wno-error
if [ ! -e sending_demo.test ]
then
	autoreconf -i
	./configure
	make
	make check
	sudo make install
fi
cd ..

# node-monitor
if [ ! -x /usr/bin/gpio ]
then
	sudo apt install wiringpi libxml2 libxml2-dev
fi
if [ ! -e node-monitor ]
then
	git clone https://github.com/edsac-status-monitor/node-monitor.git
fi
cd node-monitor/src

export CFLAGS="$(pkg-config --cflags libedsacnetworking) $(pkg-config --cflags libxml-2.0) -I../include" 
export LFLAGS="$(pkg-config --libs libedsacnetworking) $(pkg-config --libs libxml-2.0) -lm -lwiringPi"

if [ ! -x node-monitor ]
then
    for c in *.c
    do
        echo gcc -c $CFLAGS $c
	gcc -c $CFLAGS $c
    done
    gcc -o node-monitor *.o $LFLAGS 
fi
cd ../../

#archive
if [ ! -e dist-archive.tar.gz ]
then
    mkdir -p dist-archive
    for l in $(ldd node-monitor/src/node-monitor | cut -d' ' -f 3 | grep .)
    do
	echo $l
	cp $l dist-archive/
    done
    cp node-monitor/src/node-monitor dist-archive

    tar -czf dist-archive.tar.gz dist-archive
fi
