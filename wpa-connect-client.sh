#!/bin/bash

# pathectory of wpa_supplicant
pathSupplicant=/etc/wpa_supplicant

# interfaces configurations
pathIfaces=/etc/network/interfaces.d

# wiface = wireless interface
wiface=$(iw dev | grep Interface | cut -f 2 -d " ")

if [[ $wiface ]]; then
	if [ ! -n "$(ip link show $wiface | grep ,UP)" ]; then
		ip link set $wiface up
	fi

	ssids=($(iw dev $wiface scan | grep SSID | cut -f 2 -d " "))

	echo "Access points available:"

	n=1
	for ssid in ${ssids[@]}; do
		echo "$n) $ssid"
		((n++))
	done

	echo

	read -p "Choose an access point: " index

	if [ $index -gt 0 ]; then
		((index--))
	fi

	myssid=${ssids[$index]}

	ip link set $wiface down
	iw dev $wiface set type ibss

	echo

	read -sp "Password of \"$myssid\": " password; echo
	
	echo -e "auto $wiface\niface $wiface inet dhcp
	wpa-conf $pathSupplicant/$myssid.conf" > $pathIfaces/$wiface

	echo -e "ctrl_interface=/var/run/wpa_supplicant\n" > $pathSupplicant/$myssid.conf
	wpa_passphrase $myssid $password >> $pathSupplicant/$myssid.conf

	chmod 000 $pathSupplicant/$myssid.conf

	if [ -e /var/run/wpa_supplicant/$wiface ]; then
		rm /var/run/wpa_supplicant/$wiface
	fi

	ip link set $wiface up
	
	echo

	echo "Connecting..."

	wpa_supplicant -i $wiface -c $pathSupplicant/$myssid.conf -D nl80211 &> /dev/null

	/etc/init.d/networking restart &> /dev/null

	echo "Connected!"
else
	exit 0
fi
