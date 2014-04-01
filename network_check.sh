#!/bin/bash

until [ -z $1 ]
do
	if [ "$1" = "default" ]
	then
		FUNC=create_default_network
	elif [ "$1" = "custom" ]
	then
		FUNC=create_custom_network
	elif [ "$1" = "--help" ]
	then
		echo -e "use $./network_check.sh default because create default network settings or \nuse $./network_check.sh custom because create custom network settings"
		exit 0
	fi
	shift
done
		
create_custom_network() {
	sudo ip link add link eth0 name br19 type bridge
	sudo ip link add link eth0 name eth0.1071 type vlan id 1071
	sudo ip link add link eth0 name eth0.1086 type vlan id 1086
	sudo ip link add link eth0.1071 name br1071 type bridge
	sudo ip link add link eth0.1086 name br1086 type bridge
	sudo ip link set eth0 master br19
	sudo ip link set eth0.1071 master br1071
	sudo ip link set eth0.1086 master br1086

	sudo ip link set br19 up
	sudo ip link set eth0.1071 up
	sudo ip link set eth0.1086 up
	sudo ip link set br1071 up
	sudo ip link set br1086 up

	sudo ip addr del 172.18.78.15 dev eth0
	sudo ip addr add 172.18.78.15/25 dev br19
	sudo ip addr add 10.20.1.200/24 dev br1071
	sudo ip addr add 10.20.0.200/24 dev br1086

	if [ ! -f /etc/network/interfaces ]; then sudo cp /etc/network/interfaces.sample /etc/network/interfaces 2>/dev/null; fi
	if [ -f /etc/network/interfaces.new ]; then sudo rm /etc/network/interfaces.new; fi
 	if [ -f /etc/network/interfaces.old ]; then sudo rm /etc/network/interfaces.old; fi
	sudo sed 's/eth0/br19/g' /etc/network/interfaces > /etc/network/interfaces.new
	sudo mv /etc/network/interfaces /etc/network/interfaces.old
	sudo mv /etc/network/interfaces.new /etc/network/interfaces

	sudo service networking restart
	sudo ip ro add default via 172.18.78.1 2>/dev/null
}

create_default_network() {
	sudo rm /etc/network/interfaces 2>/dev/null
	sudo cp /etc/network/interfaces.sample /etc/network/interfaces 2>/dev/null
	sudo ip link del br19 2>/dev/null
	sudo ip link del eth0.1071 2>/dev/null
	sudo ip link del eth0.1086 2>/dev/null
	sudo ip link del br1071 2>/dev/null
	sudo ip link del br1086 2>/dev/null
	sudo service networking restart
	sudo ip addr add 172.18.78.15/25 dev eth0
	sudo service networking restart
	sudo ip ro add default via 172.18.78.1 2>/dev/null
}

$FUNC
