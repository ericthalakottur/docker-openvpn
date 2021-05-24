#!/bin/sh

setEnvVars () {
	echo "
export CONFIG_PATH=$CONFIG_PATH
export SERVER_IP=$SERVER_IP
export PORT=$PORT
export PROTOCOL=$PROTOCOL
	" >> /etc/profile
}

createServerConfig () {
	echo "
port 1194

proto $PROTOCOL
dev tun

ca /pki/ca.crt
cert /pki/issued/server.crt
key /pki/private/server.key

dh /pki/dh.pem

server $SUBNET $SUBNET_MASK

ifconfig-pool-persist ipp.txt

push \"redirect-gateway def1 bypass-dhcp\"

push \"dhcp-option DNS $DNS_SERVER1\"
push \"dhcp-option DNS $DNS_SERVER2\"

keepalive 10 120

auth SHA512
tls-auth /pki/ta.key 0

cipher AES-256-GCM

user nobody
group nobody

persist-key
persist-tun

status openvpn-status.log

verb 3
	" > server.conf
}

createClientConfig () {
	echo "Generating config file for $1"
	echo "
client

dev tun
proto $PROTOCOL

remote $SERVER_IP $PORT

resolv-retry infinite

nobind

user nobody
group nobody

persist-key
persist-tun

ca [inline]
cert [inline]
key [inline]

auth SHA512
remote-cert-tls server
tls-auth [inline] 1

cipher AES-256-GCM

verb 3
	" > "$CONFIG_PATH"/"$1".ovpn

	echo "<ca>" >> "$CONFIG_PATH"/"$1".ovpn
	cat /pki/ca.crt >> "$CONFIG_PATH"/"$1".ovpn
	echo "</ca>" >> "$CONFIG_PATH"/"$1".ovpn

	echo "<cert>" >> "$CONFIG_PATH"/"$1".ovpn
	cat /pki/issued/"$1".crt >> "$CONFIG_PATH"/"$1".ovpn
	echo "</cert>" >> "$CONFIG_PATH"/"$1".ovpn

	echo "<key>" >> "$CONFIG_PATH"/"$1".ovpn
	cat /pki/private/"$1".key >> "$CONFIG_PATH"/"$1".ovpn
	echo "</key>" >> "$CONFIG_PATH"/"$1".ovpn

	echo "<tls-auth>" >> "$CONFIG_PATH"/"$1".ovpn
	cat /pki/ta.key >> "$CONFIG_PATH"/"$1".ovpn
	echo "</tls-auth>" >> "$CONFIG_PATH"/"$1".ovpn
}

buildClient () {
	echo "Building Client"
	read -p "Enter number of clients: " NUM_CLIENT
	i=0
	while [ $i -lt $NUM_CLIENT ]
	do
		read -p "Enter client name: " CLIENT

		read -p "Do you want a PEM pass phrase for the client $client?(Y/n)" CLIENT_PASS_CHOICE
		if [ $CLIENT_PASS_CHOICE = "Y" ]
		then
			./usr/share/easy-rsa/easyrsa build-client-full $CLIENT
		else
			./usr/share/easy-rsa/easyrsa build-client-full $CLIENT nopass
		fi

		createClientConfig $CLIENT

		i=`expr $i + 1`
	done
}

init () {
	# set environment variables
	setEnvVars

	# iptable rules
	iptables -t nat -A POSTROUTING -s $SUBNET -o eth0 -j MASQUERADE
	iptables-save > /etc/iptables.conf

	# For CA 
	./usr/share/easy-rsa/easyrsa init-pki

	echo "Building CA"
	read -p "Do you want a CA Key Passphrase?(Y/n)" CA_PASS_CHOICE
	if [ $CA_PASS_CHOICE = "Y" ]
	then
		./usr/share/easy-rsa/easyrsa build-ca
	else
		./usr/share/easy-rsa/easyrsa build-ca nopass
	fi

	# Generate shared-secret key for tls-auth
	openvpn --genkey --secret /pki/ta.key

	# For Server
	echo "Building Server"
	read -p "Do you want a PEM pass phrase for the server?(Y/n)" SERVER_PASS_CHOICE
	if [ $SERVER_PASS_CHOICE = "Y" ]
	then
		./usr/share/easy-rsa/easyrsa build-server-full server
	else
		./usr/share/easy-rsa/easyrsa build-server-full server nopass
	fi

	createServerConfig

	buildClient

	# For Diffie-Hellman
	./usr/share/easy-rsa/easyrsa gen-dh
}

if [ ! -f "server.conf" ]
then
	read -p "Enter volume mount path: " CONFIG_PATH
	read -p "Enter server/host IP: " SERVER_IP
	read -p "Enter subnet which you would like to use(default 10.8.1.0/24): " SUBNET
	if [ -z $SUBNET ]
	then
		SUBNET=10.8.1.0/24
	fi
	read -p "Enter subnet mask(default 255.255.255.0): " SUBNET_MASK
	if [ -z $SUBNET_MASK ]
	then
		SUBNET_MASK='255.255.255.0'
	fi

	# Port
	read -p "Enter port to be used on host machine mask(default 1194): " PORT
	if [ -z $PORT ]
	then
		PORT=1194
	fi

	# Select Protocol
	echo "Which protocol would you like to use?"
	echo "1. UDP"
	echo "2. TCP"
	read -p "Enter your choice(1/2): " PROTOCOL_CHOICE
	while [ $PROTOCOL_CHOICE -ne '1' -a $PROTOCOL_CHOICE -ne '2' ]
	do
		echo "Invalid choice"
		read -p "Enter your choice(1/2): " PROTOCOL_CHOICE
	done
	if [ $PROTOCOL_CHOICE = '1' ]
	then
		PROTOCOL=udp
	else
		PROTOCOL=tcp
	fi

	# Select DNS
	echo "Which DNS would you like to use?"
	echo "1. 1.1.1.1"
	echo "2. Google Public DNS"
	echo "3. Custom"
	read -p "Enter your choice: " DNS_CHOICE
	while [ $DNS_CHOICE -lt '1' -o $DNS_CHOICE -gt '3' ]
	do
		echo "Invalid choice"
		read -p "Enter your choice: " DNS_CHOICE
	done
	case $DNS_CHOICE in
		'1')
			DNS_SERVER1='1.1.1.1'
			DNS_SERVER2='1.0.0.1'
			;;
		'2')
			DNS_SERVER1='8.8.8.8'
			DNS_SERVER2='8.8.4.4'
			;;
		'3')
			read -p "Enter DNS Server 1: " DNS_SERVER1
			read -p "Enter DNS Server 2: " DNS_SERVER2
			;;
	esac

	# easy-rsa environment variables
	read -p "Set CA config values?(Y/n): " CA_CONFIG_CHOICE
	if [ $CA_CONFIG_CHOICE = 'Y' ]
	then
		read -p "Enter DN Country: " EASYRSA_REQ_COUNTRY
		read -p "Enter DN Province: " EASYRSA_REQ_PROVINCE
		read -p "Enter DN City: " EASYRSA_REQ_CITY
		read -p "Enter DN Organization: " EASYRSA_REQ_ORG
		read -p "Enter DN email: " EASYRSA_REQ_EMAIL
		read -p "Enter DN Organizational Unit: " EASYRSA_REQ_OU
		export EASYRSA_REQ_COUNTRY EASYRSA_REQ_PROVINCE EASYRSA_REQ_CITY
		export EASYRSA_REQ_ORG EASYRSA_REQ_EMAIL EASYRSA_REQ_OU
	fi
	read -p "Set CA and cert expiration time?(Y/n): " EXP_TIME_CHOICE
	if [ $EXP_TIME_CHOICE = 'Y' ]
	then
		read -p "Enter CA expiration time in days: " EASYRSA_CA_EXPIRE
		read -p "Enter certificate expiration time in days: " EASYRSA_CERT_EXPIRE
		export EASYRSA_CA_EXPIRE EASYRSA_CERT_EXPIRE
	fi

	init

	echo "You can create new users by restarting the container"
	read -n 1 -s -r -p "Press any key to start server"
else
	iptables-restore < /etc/iptables.conf
	source /etc/profile

	read -p "Create additional clients?(Y/n): " BUILD_CLIENT_CHOICE
	if [ $BUILD_CLIENT_CHOICE = 'Y' ]
	then
		buildClient
		read -n 1 -s -r -p "Press any key to start server"
	fi
fi

# Start openvpn server
echo "Starting openvpn server"
openvpn server.conf
