#!/bin/bash

# wpa_supplicant configuration
pathSupplicant=/etc/wpa_supplicant/wpa_supplicant.conf

# wiface = wireless interface
wiface=$(iw dev | grep Interface | cut -f 2 -d " ")

# wireless interface configuration
pathWiface=/etc/network/interfaces.d/$wiface

scanAPs () {
	# Check if wireless interface is up or down
	if [ -n "$(ip link show $wiface | grep ,UP)" ]; then
		echo "$wiface is already up"
	else
		echo "$wiface is down"
		echo "Setting up wireless interface..."
		ip link set $wiface up
	fi

	# Scan access points with wireless interface and save them in an array
	echo "Scanning access points..."
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
	echo "Writing $pathWiface"

	echo "
auto $wiface
iface $wiface inet dhcp
	wpa-conf $pathSupplicant" > $pathWiface

	# wpa_supplicant file
	echo "Writing $pathSupplicant"
	wpa_passphrase $myssid $password > $pathSupplicant


	# Only root can be do anything with the file
	chmod 000 $pathWiface
	chmod 000 $pathSupplicant
}

association () {
	# Adjust operating mode
	echo "Setting down wireless interface..."
	ip link set $wiface down

	echo "Setting interface type to ibss..."
	iw dev $wiface set type ibss
	
	# Remove runtime data wpa_supplicant
	if [ -e /var/run/wpa_supplicant/$wiface ]; then
		echo "Removing /var/run/wpa_supplicant/$wiface"
		rm /var/run/wpa_supplicant/$wiface
	fi

	# Run wpa_supplicant to connect to the access point
	echo "Starting wpa_supplicant..."
	wpa_supplicant -D nl80211,wext -i $wiface -c $pathSupplicant

	# Bring up Wireless interface
	ip link set $wiface up
	
	# Reset current network
	echo "Reloading systemctl daemon..."
	systemctl daemon-reload

	echo "Restarting network..."
	/etc/init.d/networking restart
	
	echo

	# Know if there was a successful connection
	echo "Wireless interface status: "
	iw dev $wiface link
}

if [[ $wiface ]]; then
	echo -e "There is a wireless interface ($wiface)"

	echo # --------------------------------------------

	scanAPs

	echo # --------------------------------------------

	showAPs
	echo
	chooseAP

	echo # --------------------------------------------

	writeConfigurationFiles

	echo # --------------------------------------------

	association
else
	echo "There is not a wireless interface";
fi
