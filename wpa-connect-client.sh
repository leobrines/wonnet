#!/bin/bash

# pathectory of wpa_supplicant
pathSupplicant=/etc/wpa_supplicant

# interfaces configurations
pathIfaces=/etc/network/interfaces.d

# wiface = wireless interface
wiface=$(iw dev | grep Interface | cut -f 2 -d " ")

showTitle (){
	tput bold
	echo "Wireless network connection"
	tput sgr0
}

scanAPs () {
	# Check if wireless interface is up or down
	if [ ! -n "$(ip link show $wiface | grep ,UP)" ]; then
		ip link set $wiface up
	fi

	# Scan access points with wireless interface and save them in an array
	ssids=($(iw dev $wiface scan | grep SSID | cut -f 2 -d " "))
}

showAPs (){
	echo

	echo "Access points available:"

	n=1
	for ssid in ${ssids[@]}; do
		echo "$n) $ssid"
		((n++))
	done

	echo
}

chooseAP () {
	read -p "Choose an access point: " index

	# Rest one chosen number to be index of the array of access points 
	if [ $index -gt 0 ]; then
		((index--))
	fi

	myssid=${ssids[$index]}

	read -sp "Password of \"$myssid\": " password; echo

	echo
}

writeConfigurationFiles () {
	# Interface file
	echo -e "auto $wiface\niface $wiface inet dhcp
	wpa-conf $pathSupplicant/$myssid.conf" > $pathIfaces/$wiface

	# Access point file
	echo -e "ctrl_interface=/var/run/wpa_supplicant\n" > $pathSupplicant/$myssid.conf
	wpa_passphrase $myssid $password >> $pathSupplicant/$myssid.conf

	# Only root can be do anything with the file
	chmod 000 $pathSupplicant/$myssid.conf
}

adjustOperatingMode () {
	ip link set $wiface down
	iw dev $wiface set type ibss
}

association () {
	echo "Connecting..."
	# Remove runtime data wpa_supplicant
	if [ -e /var/run/wpa_supplicant/$wiface ]; then
		rm /var/run/wpa_supplicant/$wiface
	fi

	# Run wpa_supplicant to connect to the access point
	wpa_supplicant -q -i $wiface -c $pathSupplicant/$myssid.conf -D nl80211,wext > /dev/null

	# Set up wireless interface to start wpa_supplicant
	ip link set $wiface up

	# Reset current network
	echo "Restarting network..."
	/etc/init.d/networking restart > /dev/null
	
	echo

	# Know if there was a successful connection
	echo "Wireless interface status: "
	iw dev $wiface link
}

echo
showTitle

if [[ $wiface ]]; then
	scanAPs
	showAPs
	chooseAP
	
	writeConfigurationFiles

	adjustOperatingMode
	association
else
	echo "There is not a wireless interface";
fi
