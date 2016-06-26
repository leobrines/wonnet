#!/bin/bash

# wpa_supplicant configuration
pathSupplicant=/etc/wpa_supplicant/wpa_supplicant.conf

# wiface = wireless interface
wiface=$(iw dev | grep Interface | cut -f 2 -d " ")

# wireless interface configuration
pathWiface=/etc/network/interfaces.d/$wiface

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
	echo "Access points available:"

	n=1
	for ssid in ${ssids[@]}; do
		echo "$n) $ssid"
		((n++))
	done
}

chooseAP () {
	read -p "Choose an access point: " index

	# Rest one chosen number to be index of the array of access points 
	if [ $index -gt 0 ]; then
		((index--))
	fi

	myssid=${ssids[$index]}

	read -sp "Password of \"$myssid\": " password; echo
}

writeConfigurationFiles () {
	# Interface file
	echo "
auto $wiface
iface $wiface inet dhcp
	wpa-conf $pathSupplicant" > $pathWiface

	# wpa_supplicant file
	wpa_passphrase $myssid $password > $pathSupplicant


	# Only root can be do anything with the file
	chmod 000 $pathWiface
	chmod 000 $pathSupplicant
}

association () {
	echo "Connecting..."
	# Adjust operating mode
	ip link set $wiface down
	iw dev $wiface set type ibss
	
	# Remove runtime data wpa_supplicant
	if [ -e /var/run/wpa_supplicant/$wiface ]; then
		rm /var/run/wpa_supplicant/$wiface > /dev/null
	fi

	# Run wpa_supplicant to connect to the access point
	wpa_supplicant -q -i $wiface -c $pathSupplicant -D nl80211,wext > /dev/null

	# Bring up Wireless interface
	ip link set $wiface up
	
	# Reset current network
	echo "Restarting network..."
	systemctl daemon-reload > /dev/null
	/etc/init.d/networking restart > /dev/null
	
	echo

	# Know if there was a successful connection
	echo "Wireless interface status: "
	iw dev $wiface link
}

echo

showTitle

echo # --------------------------------------------

if [[ $wiface ]]; then
	scanAPs

	showAPs
	echo
	chooseAP

	writeConfigurationFiles

	echo

	association
else
	echo "There is not a wireless interface";
fi
