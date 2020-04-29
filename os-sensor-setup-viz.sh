#!/bin/sh

# This script is meant to easily find the available network interfaces,
# configure the interface to link-local, find a sensor on said interface, 
# and start the visualizer with the lidar_mode of your choosing.
# Source this script to keep the environment variables after script is finished.
# ie. . script-name.sh

GREEN="\033[1;32m" #text green
NOCOLOR="\033[0m" #text no coloring

# Find the interface IP addresses available
echo "Finding the available interfaces to choose from..."
ip addr show | grep "inet\b" | awk '{print NR " - " $NF ": " $2}' 
# Assign possible interfaces to environment variables
echo "Assigning interfaces to variables, eg INTERFACE1, INTERFACE2, etc...."
eval $(ip addr show | grep "inet\b" | awk '{print $NF}' | cut -d/ -f1 | awk '{print "INTERFACE"NR"="$1}')	
echo "Assigning interface IP addresses to variables, eg IP1, IP2, etc...\n"
eval $(ip addr show | grep "inet\b" | awk '{print $2}' | cut -d/ -f1 | awk '{print "IP"NR"="$1}')

# Check for Zsh vs Bash for read cmd.
if [ -n "$ZSH_VERSION" ]; then
   # assume Zsh
    read "ANSWER?Select the interface your sensor is connected to. (1, 2, 3, etc.) "

elif [ -n "$BASH_VERSION" ]; then
   # assume Bash
    read -p "Select the interface your sensor is connected to. (1, 2, 3, etc.) " ANSWER
else
	echo "Shell type not compatible please use bash or zsh. "
	return 1
fi

SEL_IP=${(P)${:-IP$ANSWER}}
SEL_INTERFACE=${(P)${:-INTERFACE$ANSWER}}
echo "Selected interface and IP are: ${GREEN}$SEL_INTERFACE${NOCOLOR} : ${GREEN}$SEL_IP${NOCOLOR}"

echo "Setting selected interface to link-local mode...."
nmcli con modify $SEL_INTERFACE ipv4.method link-local
echo "$SEL_INTERFACE interface mode is $(nmcli con show $SEL_INTERFACE | grep ipv4.method)"
echo "Exporting interface IP: $SEL_IP as evironment variable udp_ip..."
export udp_ip=$SEL_IP
echo "udp_ip is ${GREEN}$SEL_IP${NOCOLOR}"

		
# Find the sensor hostname using avahi-browse
echo "Searching for sensor hostname..."
# Take only the first instance of the hostname of the sensor if there are multiple.
SENSOR_NAME=$(avahi-browse -lrt _roger._tcp | grep $SEL_INTERFACE -A 5 | awk '/hostname/ {print $3}' | awk 'NR==1{print $1}' | sed -e 's/.*\[//' -e 's/\].*//') 

echo "Sensor hostname is $SENSOR_NAME"
echo "Exporting sensor hostname $SENSOR_NAME as envirnoment variable os_hostname..."
export os_hostname=$SENSOR_NAME	
echo "os_hostname is ${GREEN}$os_hostname${NOCOLOR}"
echo "Testing connection to sensor with get_sensor_info..."
http http://$os_hostname/api/v1/sensor/cmd/get_sensor_info/


# Check for Zsh vs Bash for read cmd.
if [ -n "$ZSH_VERSION" ]; then
	# assume Zsh
	echo "Select form the sensor modes below or type 'n' to skip the viz and exit? \n
	1 - 512x10\n
	2 - 512x20\n
	3 - 1024x10\n
	4 - 1024x20\n
	5 - 2048x10\n
	n - Skip viz and exit\n"
	read "ANSWER?Enter 1, 2, 3, 4, 5, or n: "
elif [ -n "$BASH_VERSION" ]; then
	# assume Bash
	echo "Select form the sensor modes below or type 'n' to skip the viz and exit? \n
	1 - 512x10\n
	2 - 512x20\n
	3 - 1024x10\n
	4 - 1024x20\n
	5 - 2048x10\n
	n - Skip viz and exit\n"
	read -p "Enter 1, 2, 3, 4, 5, or n: " ANSWER
else
	echo "Shell type not compatible please use bash or zsh. "
	return 1
fi

lidar_mode=("512x10" "512x20" "1024x10" "1024x20" "2048x10")
if [ -n "$ZSH_VERSION" ]; then
	# assume Zsh leave ANSWER 1 based.
elif [ -n "$BASH_VERSION" ]; then
	# assume Bash change to zero base for indexing arrays.
	ANSWER=$ANSWER-1
else
	echo "Shell type not compatible please use bash or zsh. "
	return 1
fi

echo "lidar_mode[$ANSWER] is ${GREEN}$lidar_mode[$ANSWER]${NOCOLOR}"

# Run the viz or not.
case "$ANSWER" in
	1|2|3|4|5)
		# Start the Viz
		 ~/code/shared_sw/ouster_example/ouster_viz/build/simple_viz -m $lidar_mode[$ANSWER] $os_hostname $udp_ip
		return 0
		;;
	[nN]|[nN]*)
		echo "Skipping viz and exiting..."
		echo "udp_ip is $SEL_IP"
		echo "os_hostname is $os_hostname"
		return 0
		;;
	*)
		echo "Invalid selection, please input a lidar mode (eg. 1024x10) or type n to skip the viz. "
		return 1
		;;
esac
