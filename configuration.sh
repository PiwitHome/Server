#!/bin/bash

#https://github.com/PiwitHome/Server.git 

echo "####install FHEM####"
if ! grep -q "^deb http://debian.fhem.de/nightly/ /" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
	sudo wget -qO - http://debian.fhem.de/archive.key | sudo apt-key add -
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

echo "####FHEM Config####"
#activate telnet 
if !(sudo grep -Po "serverVersion \K\d+\.*\d*" /opt/fhem/fhem.cfg | grep -q  "0.02"); then
        echo "stop fhem for new configuration"
        sudo service fhem stop
		sudo sed -i '$ a define telnetPort telnet 7072 global' /opt/fhem/fhem.cfg
		sudo service fhem start
fi

# if no server version available, then initial configure and set to version 0.01
if !(sudo grep -Po "serverVersion \K\d+\.*\d*" /opt/fhem/fhem.cfg); then
	echo "####install snips####"
	sudo apt-get -y install apt-transport-https
	sudo apt-get update
	sudo apt-get install -y dirmngr

	sudo bash -c  'echo "deb   https://raspbian.snips.ai/stretch stable main" > /etc/apt/sources.list.d/snips.list'
	sudo apt-key adv --keyserver pgp.surfnet.nl --recv-keys D4F50CDCA10A2849
	sudo apt-get update
	sudo apt-get install -y snips-platform-voice
	sudo apt-get install -y snips-watch

	echo "####configure snips####"
	sudo rm -r /usr/share/snips/assistant
	sudo unzip /home/pi/Server/DE-Snips/assistant_proj.zip -d /usr/share/snips/
	sudo chmod 777 /usr/share/snips/assistant
	sudo systemctl restart "snips*"

	echo "####MQTT for FHEM####"
	sudo cpan install Net::MQTT::Simple::SSL
	sudo cpan install Net::MQTT::Constants
	sudo apt-get -y install mosquitto mosquitto-clients
	
	echo "####install nmap####"
	apt-get install -y libnmap-parser-perl
	
	echo "####configure nmap####"
	echo -en '\
	define ipScanner Nmap 192.168.2.100/24;\
	attr ipScanner interval 300;\
	attr ipScanner sudo 1;\
	attr ipScanner userattr piwit;\
	\nquit\n' | nc localhost 7072
	echo -en '\
	define nIPScannerSetIP notify ipScanner:running {my $a=`ip -f inet addr show | grep -Po "inet \\\K[\\\d.]+/24"`;;$a=~s/\\n//g;;Log 1, $a;; fhem("modify ipScanner ".$a);;}\
	\nquit\n' | nc localhost 7072
	
	echo "####install broadlink####"
	sudo apt-get -y install libcrypt-cbc-perl
	sudo apt-get -y install libcrypt-rijndael-perl
	sudo apt -y install libssl-dev
	sudo cpan Crypt/OpenSSL/AES.pm
	echo "####configure broadlink####"
	echo -en '\
	define nBroadlinkUpdateIP notify ipScanner:.*_macVendor:.*Broadlin.* {my $macvendortomac=$EVTPART0;;$macvendortomac=~s/_macVendor:/_macAddress/g;;my $ip=$macvendortomac;;$ip=~s/_macAddress//g;;my $mac=ReadingsVal("ipScanner",$macvendortomac,"noIP");;my $broadlinkname="Broadlink_".$mac;;$broadlinkname=~s/:/_/g;;if(exists($defs{$broadlinkname})&&InternalVal($broadlinkname,"HOST","noIP") ne $ip){fhem("modify ".$broadlinkname." ".$ip." ".$mac." rmpro");;fhem("set ".$broadlinkname." getTemperature");;fhem("save");;}elsif(!exists($defs{$broadlinkname})){fhem("define ".$broadlinkname." Broadlink ".$ip." ".$mac." rmpro");;fhem("set ".$broadlinkname." getTemperature");;fhem("save");;};;};\
	attr nBroadlinkUpdateIP userattr piwit;\
	\nquit\n' | nc localhost 7072
	
	echo "####install YeeLight####"
	sudo cpan install JSON::XS
	echo -en '\
	update all https://raw.githubusercontent.com/thaliondrambor/32_YeeLight.pm/master/controls_YeeLight.txt;\
	reload 32_YeeLight.pm;\
	\nquit\n' | nc localhost 7072
	
	echo "####configure YeeLight####"
	#define YeeLight_34_CE_00_8B_63_93 YeeLight 192.168.2.105
	echo -en '\
	define nYeelightUpdateIP notify ipScanner:.*_ip:.* {my $iptomac=$EVTPART0;;$iptomac=~s/_ip:/_macAddress/g;;my $mac=ReadingsVal("ipScanner",$iptomac,"noIP");;if(index($mac,"34:CE:00")>=0){my $yeename="YeeLight_".$mac;;$yeename=~s/:/_/g;;if(exists($defs{$yeename})&&InternalVal($yeename,"HOST","noIP") ne $EVTPART1){fhem("modify ".$yeename." ".$EVTPART1);;}elsif(!exists($defs{$yeename})){fhem("define ".$yeename." YeeLight ".$EVTPART1);;};;};;};\
	attr nYeelightUpdateIP userattr piwit;\
	\nquit\n' | nc localhost 7072
	
		
	# set first serverVersion
	echo -en "attr global userattr serverVersion\nquit\n" | nc localhost 7072
	echo -en "attr global serverVersion 0.01\nquit\n" | nc localhost 7072 #https://forum.fhem.de/index.php/topic,66616.0.html
	echo -en "save\nquit\n" | nc localhost 7072
fi



#version 0.02
if sudo grep -Po "serverVersion \K\d+\.*\d*" /opt/fhem/fhem.cfg | grep -q  "0.01"; then
 echo  "update 0.01"
  echo  "update 0.011"
 echo -en "save\nquit\n" | nc localhost 7072
# sudo sed 's/.*attr global serverVersion.*/attr global serverVersion 0.02/' /opt/fhem/fhem.cfg
else
 echo  "no update"

fi














