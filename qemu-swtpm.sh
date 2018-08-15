#!/bin/bash

#---------------------------------------------
# Author : Byng.Zeng
# Date   : 2018-08-01
#---------------------------------------------

PATH_VTPM=~/workspace/vtpm
PATH_HOST=${PATH_VTPM}/qemu_swtpm/host

SEABIOS=${PATH_HOST}/seabios-tpm/out
UBUNTU=${PATH_VTPM}/ubuntu/ubuntu-16.04.4-desktop-amd64.iso
MYTPM=/tmp/myvtpm0
SWTMP_SOCK=${MYTPM}/swtpm-sock

function help_menu()
{
	echo '========================================='
	echo '         Qemu for swtpm'
	echo '========================================='
	echo '-d:'
	echo '  download source code'
	echo '-e:'
	echo '  setup build envirnoment'
	echo '-i:'
	echo '  build and install libtpms, swtpm and qemu'
	echo '-s:'
	echo '  setup swtpm'
	echo '-m'
	echo '  setup VM'
}

function download_code()
{
	git clone https://github.com/stefanberger/seabios-tpm
	git clone https://github.com/stefanberger/libtpms
	git clone https://github.com/stefanberger/swtpm
	git clone https://github.com/qemu/qemu.git

	cd ${PATH_HOST}/qemu
	rm -rf capstone
	git clone https://github.com/qemu/capstone.git
	rm -rf dtc
	git clone https://github.com/qemu/dtc.git
	cd ${PATH_HOST}/qemu/ui
	rm -rf keycodemapdb
	git clone https://github.com/qemu/keycodemapdb.git
}

function setup_env()
{
	sudo apt-get install build-essential libtool automake libgmp-dev libnspr4-dev libnss3-dev openssl libssl-dev git iasl glib-2.0 libglib2.0-0 libglib2.0-dev libtasn1-6-dev tpm-tools libfuse-dev libgnutls-dev libsdl1.2-dev expect gawk socat libfdt-dev
}

function qemu_install()
{
	# build seabios
	echo 'build and install seabios-tpm'
	cd ${PATH_HOST}/seabios-tpm
	make

	# install libtpms
	echo 'build and install libtpms'
	cd ${PATH_HOST}/libtpms
	./bootstrap.sh
	./configure --prefix=/usr --with-openssl
	make
	sudo make install
        echo 'libtpms done.'

	# install swtpm
	echo 'build and install swtpm'
	cd ${PATH_HOST}/swtpm
	./bootstrap.sh
	./configure --prefix=/usr --with-openssl
	make
	make check
	sudo make install
	echo 'cp /usr/etc/swtpm_setup.conf to /etc/swtpm_setup.conf'
	sudo cp /usr/etc/swtpm_setup.conf /etc/swtpm_setup.conf
        echo 'swtpm done.'

	# install qumu-tpm
	echo 'build and install qemu'
	cd ${PATH_HOST}/qemu
	./configure --enable-kvm --enable-tpm --enable-sdl
	#./configure --disable-git-update
	scripts/git-submodule.sh update  ui/keycodemapdb dtc
	make
	sudo make install
        echo 'qemu done.'
}

function qemu_uninstall()
{
	# install qumu-tpm
	echo 'uninstall qemu'
	cd ${PATH_HOST}/qemu
	./configure --enable-kvm --enable-tpm --enable-sdl
	#./configure --disable-git-update
	#scripts/git-submodule.sh update  ui/keycodemapdb dtc
	make
	sudo make uninstall
}

function qemu_swtpm_setup()
{
	if [ ! -d ${MYTPM} ]; then
		mkdir ${MYTPM}
	fi
	sudo rm -rf ${MYTPM}/*
	chown -R tss:root ${MYTPM}
	swtpm socket --tpmstate dir=${MYTPM} \
  		--ctrl type=unixio,path=${SWTMP_SOCK} \
  		--log level=20
}

function qemu_vm_setup()
{
	qemu-system-x86_64 -display sdl -accel kvm -cdrom ${UBUNTU} \
  		-m 1024 -boot d -bios ${SEABIOS}/bios.bin -boot menu=on \
  		-chardev socket,id=chrtpm,path=${SWTMP_SOCK} \
  		-tpmdev emulator,id=tpm0,chardev=chrtpm \
  		-device tpm-tis,tpmdev=tpm0

}

if [ $# == 0 ]; then
	help_menu
else
	while getopts 'deisvmu:' opt
	do
		case ${opt} in
		d):
			download_code
		;;
		e):
			setup_env
		;;
		i):
			qemu_install
		;;
		u):
			qemu_uninstall ${OPTARG}
		;;
		s):
			qemu_swtpm_setup
		;;
		m):
			qemu_vm_setup
		;;
		esac
	done
fi
