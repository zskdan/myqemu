#!/bin/bash
# set -x

# This script is a wrapper for starting qemu like a daemon with for 
# debugging/Hacking Linux Kernel.
#
#    - Virtual Networking with tuntap and bridges
#    - Monitoring on unix socket.
#    - Debugging with gdbserver listning on 1234 tcp port.
#
# CopyLeft 2009 OpenWide 
# Written by Zakaria ElQotbi <zakaria.elqotbi@openwide.fr>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# Requirement :
#     kqemu (optionnal)
#     bridge-utils
#     tunctl : uml-utilities.
HDA_IMAGE="/media/FREECOM/qemu/Fedora2.img"
nface="eth0"
BRIDGE="NO"

if [ `id -u` -ne 0 ]; then
  echo "You should run the script as root, exiting."
  exit 1
fi


do_usage()
{
	echo "Usage $0 start|stop [-d]"
	exit 2
}

do_start()
{
	if [ -f /tmp/myqemu ]; then
		echo "image already running exiting !!"
		exit 1
	fi
	if [ "$2" == "-debug" ]; then
		DEBUG="-s -S"
 	fi
  if [ ! -f "$HDA_IMAGE" ]; then
    echo "image "$HDA_IMAGE" not found !!"
    exit 1  
  fi
	modprobe tun
	modprobe kqemu 

	USERID=`whoami`
	iface=` tunctl -b -u $USERID`
	echo $iface > /tmp/myqemu

	qemu -s -S -k fr -hda $HDA_IMAGE -net nic,vlan=0 -net tap,vlan=0,ifname=$iface,script=no -m 512 -monitor unix:/tmp/myqemu.sock,server,nowait -serial unix:/tmp/myqemu-serial.sock,server,nowait -serial tcp:localhost:4444,server,nowait &
	
  if [ "$BRIDGE" = "YES" ]; then 
  	 ifconfig $nface down
	   brctl addbr br0

  	 brctl addif br0 $nface $iface
  
	   ifconfig $nface up
     ifconfig $iface up

	  # line added for OpenWide internal network
  	 route del -net 192.168.3.0 netmask 255.255.255.0 dev $nface

	   killall dhclient 2> /dev/null
  	 dhclient br0
  else
     ifconfig $iface 192.168.4.1
     echo 1 > /proc/sys/net/ipv4/ip_forward
     iptables -t nat -A POSTROUTING -o $nface -j MASQUERADE
  fi

	echo "qemu starting done for monitoring use socat :"
	echo "socat - unix-connect:/tmp/myqemu.sock "
}

do_stop()
{
	iface=`cat /tmp/myqemu`
	killall qemu
  ifconfig $iface down
  tunctl -d $iface &> /dev/null
  if [ "$BRIDGE" = "YES" ]; then 
	   ifconfig br0 down
     brctl delbr br0
  	 route add -net 192.168.3.0 netmask 255.255.255.0 dev $nface 
	   route add default gw 192.168.3.1
  else 
     ifconfig $iface down
     echo 1 > /proc/sys/net/ipv4/ip_forward
     iptables -t nat -D POSTROUTING -o $nface -j MASQUERADE
  fi
  rm /tmp/myqemu
}

case "$1" in
	"start")
		do_start
		;;
	"stop")
		do_stop
		;;
	*)
		do_usage
		;;
esac

