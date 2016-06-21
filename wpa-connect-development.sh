#!/bin/bash

# pathectory of wpa_supplicant
pathSupplicant=/etc/wpa_supplicant

# interfaces configurations
pathIfaces=/etc/network/interfaces.d

# wiface = wireless interface
wiface=$(iw dev | grep Interface | cut -f 2 -d " ")

if [[ $wiface ]]; then
	echo -e "There is a wireless interface ($wiface)"

	# Check if wireless interface is up or down
	if [ -n "$(ip link show $wiface | grep ,UP)" ]; then
		echo "$wiface is up"
	else
		echo "$wiface is down"
		echo "Setting up wireless interface..."
		ip link set $wiface up
	fi

	echo "Scanning access points..."
	# Scan access points with wireless interface and save them in an array
	ssids=($(iw dev $wiface scan | grep SSID | cut -f 2 -d " "))

	echo

	echo "Access points available:"

	# Show all scanned access points
	n=1
	for ssid in ${ssids[@]}; do
		echo "$n) $ssid"
		((n++))
	done

	echo

	read -p "Choose an access point: " index

	# Rest one chosen number to be index of the array of access points 
	if [ $index -gt 0 ]; then
		((index--))
	fi

	myssid=${ssids[$index]}

	echo

	# Set down wireless interface to set his type to ibss
	echo "Setting down wireless interface..."
	ip link set $wiface down

	echo "Setting interface type to ibss..."
	iw dev $wiface set type ibss

	echo

	read -sp "Password of \"$myssid\": " password; echo
	
	# Create or modify all file, write a configuration file interface
	echo -e "auto $wiface\niface $wiface inet dhcp
	wpa-conf $pathSupplicant/$myssid.conf" > $pathIfaces/$wiface

	echo

	echo "Creating $pathSupplicant/$myssid.conf"

	echo -e "ctrl_interface=/var/run/wpa_supplicant\n" > $pathSupplicant/$myssid.conf
	# Write ssid and password of the chosen access point
	wpa_passphrase $myssid $password >> $pathSupplicant/$myssid.conf

	# Only root can be do anything with the file
	chmod 000 $pathSupplicant/$myssid.conf

	# If the wireless interface is already running, then it'll be removed to run wpa_supplicant
	if [ -e /var/run/wpa_supplicant/$wiface ]; then
		echo "Removing /var/run/wpa_supplicant/$wiface"
		rm /var/run/wpa_supplicant/$wiface
	fi

	# Set up wireless interface to start wpa_supplicant
	echo "Setting up interface..."
	ip link set $wiface up

	echo "Starting wpa_supplicant..."

	echo
	
	# Run wpa_supplicant to connect to the access point
	wpa_supplicant -i $wiface -c $pathSupplicant/$myssid.conf -D nl80211

	echo

	# For reset current network
	/etc/init.d/networking restart
	
	echo

	# For know if there was a successful connection
	echo "Link status: "
	iw dev $wiface link
else
	echo "There is not a wireless interface";
fi
