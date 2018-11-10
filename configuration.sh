#!/bin/bash

echo "####install FHEM####"
if ! grep -q "^deb http://debian.fhem.de/nightly/ /" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
	wget -qO - http://debian.fhem.de/archive.key | apt-key add -
	sudo sh -c 'echo "deb http://debian.fhem.de/nightly/ /" >> /etc/apt/sources.list'
	sudo apt-get update
	sudo apt-get -y install fhem
fi

echo "####set authorization####"
if ! sudo grep -q "^fhem All=NOPASSWD: ALL" /etc/sudoers; then
	sudo sh -c "echo \"fhem All=NOPASSWD: ALL\" >> /etc/sudoers"
fi
echo "set authorization nmap"
if ! sudo grep -q "^fhem ALL=(ALL) NOPASSWD:/usr/bin/nmap" /etc/sudoers; then
	sudo sh -c "echo \"fhem ALL=(ALL) NOPASSWD:/usr/bin/nmap\" >> /etc/sudoers"
fi

echo "####edit config####"
#https://forum.fhem.de/index.php/topic,66616.0.html
echo -en "attr WEB editConfig 1\nquit\n" | nc localhost 7072

echo "####broadlink dependency####"
sudo apt-get -y install libcrypt-cbc-perl
sudo apt-get -y install libcrypt-rijndael-perl
sudo apt -y install libssl-dev
sudo cpan Crypt/OpenSSL/AES.pm


echo "####install snips####"
sudo apt-get -y install apt-transport-https
sudo apt-get update
sudo apt-get install -y dirmngr

sudo bash -c  'echo "deb   https://raspbian.snips.ai/$(lsb_release -cs) stable main" > /etc/apt/sources.list.d/snips.list'

sudo apt-key adv --keyserver pgp.mit.edu --recv-keys D4F50CDCA10A2849
sudo apt-get update
sudo apt-get install -y snips-platform-voice
sudo apt-get install -y snips-watch

echo "####configure snips####"
sudo rm -r /usr/share/snips/assistant
sudo unzip DE-Snips/assistant_proj.zip -d /usr/share/snips/
sudo chmod 777 /usr/share/snips/assistant
sudo systemctl restart "snips*"

echo "####MQTT for FHEM####"
sudo cpan install Net::MQTT::Simple::SSL
sudo cpan install Net::MQTT::Constants
sudo apt-get -y install mosquitto mosquitto-clients










