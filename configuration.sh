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
	# try out both keyservers
	sudo apt-key adv --keyserver pgp.surfnet.nl --recv-keys D4F50CDCA10A2849
	sudo apt-key adv --keyserver pgp.mit.edu --recv-keys D4F50CDCA10A2849 
	sudo apt-get update
	sudo apt-get install -y snips-platform-voice
	sudo apt-get install -y snips-watch
	sudo apt-get install -y snips-injection

	echo "####configure snips####"
	sudo rm -r /usr/share/snips/assistant
	sudo unzip /home/pi/Server/DE-Snips/assistant_proj.zip -d /usr/share/snips/
	sudo chmod 777 /usr/share/snips/assistant
	sudo systemctl restart "snips*"

	echo "####install MQTT for FHEM####"
	sudo PERL_MM_USE_DEFAULT=1 cpan -i CPAN 
	sudo cpan install Net::MQTT::Simple::SSL
	sudo cpan install Net::MQTT::Constants
	sudo apt-get -y install mosquitto mosquitto-clients
	
	echo "####install nmap####"
	apt-get install -y libnmap-parser-perl
	
	echo "####install broadlink####"
	sudo apt-get -y install libcrypt-cbc-perl
	sudo apt-get -y install libcrypt-rijndael-perl
	sudo apt -y install libssl-dev
	export PERL_MM_USE_DEFAULT=1
	sudo echo "yes" | sudo cpan Crypt/OpenSSL/AES.pm
	
	echo "####install YeeLight####"
	sudo cpan install JSON::XS
	
	echo "####set global Attributes####"
	#piwit: device|technical, type (light,camera...)
	#piwitDisplay: Homescreen -> displayed on homescreen
	echo -en '\
	{fhem("attr global userattr ".AttrVal("global","userattr","")." piwit piwitDisplay setListt piwitTalkExplanationDE serverVersion")}; \
	\nquit\n' | nc localhost 7072
	
	echo -en '\
	save; \
	\nquit\n' | nc localhost 7072
	
	echo "####configure MQTT for FHEM####"
	
	echo -en '\
	define mqtt MQTT 127.0.0.1:1883; \
	define snipsListener MQTT_DEVICE; \
	attr snipsListener IODev mqtt; \
	attr snipsListener publishSet_talk hermes/tts/say; \
	attr snipsListener stateFormat transmission-state; \
	attr snipsListener subscribeReading_hotword hermes/hotword/default/detected; \
	attr snipsListener subscribeReading_state hermes/asr/textCaptured; \
	define parseJson expandJSON snipsListener:json:.{.*}; \
	define nParseJson notify snipsListener setreading snipsListener json $EVENT; \
	define nTalk notify snipsListener:text:.* set talk $EVENT; \
	define nTalkAnswer notify talk:answers:.* {system('\''mosquitto_pub -h localhost -p 1883 -t hermes/tts/say -m "{\"text\":\"'\''.ReadingsVal("talk","answers","").'\''\",\"lang\":\"de\",\"siteId\":\"default\"}"'\'')}; \
	define nTalkErr notify talk:err:.* {system('\''mosquitto_pub -h localhost -p 1883 -t hermes/tts/say -m "{\"text\":\"'\''.(["ich weiß es nicht","ich habe dich nicht verstanden"]->[rand(3)]).'\''\",\"lang\":\"de\",\"siteId\":\"default\"}"'\'')}; \
	save; \
	\nquit\n' | nc localhost 7072
	
	echo -en '\
	define updateKi dummy;\
	attr updateKi userattr type;\
	attr updateKi type Switch; \
	attr updateKi room hidden;\
	attr updateKi piwitDisplay noHomescreen;\
	attr updateKi piwit technical,updateKi;\
	attr updateKi setList off on;\
	attr updateKi userattr updateKiDevices updateKiRooms
	attr updateKi updateKiDevices ["Badlicht","Kuechenlicht","Wohnzimmerlicht"];\
	setreading updateKi piwit configuration;\
	define nupdateKiON notify updateKi:on { my @rooms;;my @devices;;foreach my $dev (devspec2array("piwit=device.*")){foreach my $device (split(",",AttrVal($dev,"alias",$dev))){push @devices,$device if (!grep(/^$device$/,@devices))};;foreach my $room (split(",",AttrVal($dev,"room",""))){push @rooms,$room if (!grep(/^$room$/,@rooms));;}};;fhem("attr talk T2F_keywordlist &devices = ".join(",",sort @devices)."\\n&rooms = ".join(",",sort @rooms));;fhem("attr updateKi updateKiDevices [\"".join("\",\"",sort @devices)."\"]");;fhem("attr updateKi updateKiRooms [\"".join("\",\"",sort @rooms)."\"]");; \
	system("echo '\''{\"operations\":[[\"addFromVanilla\",{\"geraet\":".AttrVal("updateKi","updateKiDevices","")."}]]}\'\'' > injections.json && mosquitto_pub -t hermes/injection/perform -f injections.json");;\
	system("echo '\''{\"operations\":[[\"addFromVanilla\",{\"ort\":".AttrVal("updateKi","updateKiRooms","")."}]]}\'\'' > injections.json && mosquitto_pub -t hermes/injection/perform -f injections.json");;\
	};\
	save; \
	\nquit\n' | nc localhost 7072
	
	#--original
	#define nupdateKiON notify updateKi:on { my @rooms;;my @devices;;foreach my $dev (devspec2array("piwit=device")){foreach my $device (split(",",AttrVal($dev,"alias",$dev))){push @devices,$device if (!grep(/^$device$/,@devices))};;foreach my $room (split(",",AttrVal($dev,"room",""))){push @rooms,$room if (!grep(/^$room$/,@rooms));;}};;fhem("attr talk T2F_keywordlist &devices = ".join(",",sort @devices)."\\n&rooms = ".join(",",sort @rooms));;};\
	#echo '{"operations":[["addFromVanilla",{"geraet":["Badlicht","Kuechenlicht","Wohnzimmerlicht"]}]]}' > injections.json && mosquitto_pub -t hermes/injection/perform -f injections.json
	#--- ok funktioniert
	#system("echo '{\"operations\":[[\"addFromVanilla\",{\"geraet\":[\"Badlicht\",\"Kuechenlicht\",\"Wohnzimmerlicht\"]}]]}' > injections.json && mosquitto_pub -t hermes/injection/perform -f injections.json");;
	#echo -en '\
	#attr talk T2F_keywordlist &devices = flurr \\
	#&rooms = flurr\	
	#\nquit\n' | nc localhost 7072
			
	echo -en '\
	define talk Talk2Fhem;\
	modify talk \
	(zustand|status|ist|welchen|hat) (.*) (@devices)(.*)? = ( answer => {(Value((devspec2array("a:alias~$3"))[0]) || (Value("$3")) ||  "ich weiß es nicht")} ) \
	?(bitte) && (@devices) && (\S+)(schalten|machen)?$ = (cmd=>"set $2@.* $3{true=>on, false=>off};; set a:alias~$2@.* $3{true=>on, false=>off}", answer => {"ok"} ) \
	?(bitte) && alle && (@rooms) && (\S+)(schalten|machen)?$ = (cmd=>"set room=.*$2@.* $3{true=>on, false=>off}", answer => {"ok"} )\
	\nquit\n' | nc localhost 7072
	
	
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
	
	echo "####configure broadlink####"
	echo -en '\
	define nBroadlinkUpdateIP notify ipScanner:.*_macVendor:.*Broadlin.* {my $macvendortomac=$EVTPART0;;$macvendortomac=~s/_macVendor:/_macAddress/g;;my $ip=$macvendortomac;;$ip=~s/_macAddress//g;;my $mac=ReadingsVal("ipScanner",$macvendortomac,"noIP");;my $broadlinkname="Broadlink_".$mac;;$broadlinkname=~s/:/_/g;;if(exists($defs{$broadlinkname})&&InternalVal($broadlinkname,"HOST","noIP") ne $ip){fhem("modify ".$broadlinkname." ".$ip." ".$mac." rmpro");;fhem("set ".$broadlinkname." getTemperature");;fhem("save");;}elsif(!exists($defs{$broadlinkname})){fhem("define ".$broadlinkname." Broadlink ".$ip." ".$mac." rmpro");;fhem("set ".$broadlinkname." getTemperature");;fhem("save");;};;};\
	attr nBroadlinkUpdateIP userattr piwit;\
	\nquit\n' | nc localhost 7072
	
	echo "####configure YeeLight####"
	echo -en '\
	update all https://raw.githubusercontent.com/thaliondrambor/32_YeeLight.pm/master/controls_YeeLight.txt;\
	reload 32_YeeLight.pm;\
	\nquit\n' | nc localhost 7072
	
	echo "####configure YeeLight####"
	echo -en '\
	define LightsceneList dummy; \
	attr LightsceneList room hidden; \
	attr LightsceneList setList Select.. on off; \
	attr LightsceneList piwit list,lightsceens; \
	attr LightsceneList piwitDisplay Homescreen; \
	define LightsceneList_UpdateYeelightLightscenes notify LightsceneList:updateList:.* {fhem("attr YeeLight.* setListt ".AttrVal("LightsceneList","setList","Na"));;fhem("attr PiwitHue.* userattr setListt");;fhem("attr PiwitHue.* setListt ".AttrVal("LightsceneList","setList","Na"));;fhem("save");;}
	\nquit\n' | nc localhost 7072
	
	echo "####ScenarioList,WeekdayTimer List, EventList####"
	echo -en '\
	define ScenarioList dummy
	attr ScenarioList userattr ScenarioList EventList WeekdayTimer
	attr ScenarioList EventList Select.. 
	attr ScenarioList WeekdayTimer 
	attr ScenarioList room hidden
	attr ScenarioList setList Select.. 
	attr ScenarioList sortby setList
	attr ScenarioList piwit list,scenarios
	attr ScenarioList piwitDisplay Homescreen
	attr ScenarioList useSetExtensions 1
	attr ScenarioList piwitTalkExplanationDE Ich möchte gerne schlafengehen, aufstehen, fernsehen schauen oder wie auch immer du dir dein scenario erstellt hast
	define ScenarioListOn notify ScenarioList {fhem("set ".$EVENT." on;;")}
	\nquit\n' | nc localhost 7072
	
	
	#define YeeLight_34_CE_00_8B_63_93 YeeLight 192.168.2.105
	echo -en '\
	define nYeelightUpdateIP notify ipScanner:.*_ip:.* {my $iptomac=$EVTPART0;;$iptomac=~s/_ip:/_macAddress/g;;my $mac=ReadingsVal("ipScanner",$iptomac,"noIP");;if(index($mac,"34:CE:00")>=0){my $yeename="YeeLight_".$mac;;$yeename=~s/:/_/g;;if(exists($defs{$yeename})&&InternalVal($yeename,"HOST","noIP") ne $EVTPART1){fhem("modify ".$yeename." ".$EVTPART1);;}elsif(!exists($defs{$yeename})){fhem("define ".$yeename." YeeLight ".$EVTPART1);;fhem("attr ".$yeename." piwit device,light");;fhem("attr ".$yeename." piwitDisplay Homescreen");;};;};;};\
	attr nYeelightUpdateIP piwit notify,yeelight;\
	\nquit\n' | nc localhost 7072
	# on new YeeLight add lightsceen list and reading Lightscene,  
	echo -en '\
	define nYeeLightAddeddefine notify global:DEFINED.*YeeLight.* {fhem("attr ".$EVTPART1." setListt ".AttrVal("LightsceneList","setList","Na"));;fhem("setreading ".$EVTPART1." Lightscene ".AttrVal("LightsceneList","setList","Na"));;fhem("attr ".$EVTPART1." piwitDisplay Homescreen");;fhem("save");;};\
	define LightsceneList_StartLightsceneYeeLight notify YeeLight.*:Lightscene:.* {fhem("attr ".$EVTPART1." lightSceneDevice ".$NAME);;fhem("set ".$EVTPART1." on ");;};\
	\nquit\n' | nc localhost 7072
	
	
	
	
	echo "####Run the IP Scanner####"
	echo -en '\
	set ipScanner statusRequest; \
	\nquit\n' | nc localhost 7072
	
	# sound to 100% - later the user can configure it
	sudo amixer set PCM -- 100%
	
	echo "####Welcome Text####"
	echo -en '\
	setreading talk answers Hallo ich heiße Snips. Du kannst jetzt die Appp starten und Geräte anlegen. Wenn du hilfe zu einem Gerät brauchst sag einfach, hey snips, hilf mir bitte mit dem Wohnzimmerlicht; \
	\nquit\n' | nc localhost 7072
	
	#echo -en '\
	#set updateKi on; \ 
	#\nquit\n' | nc localhost 7072
	
	# set first serverVersion :)
	#echo -en "attr global userattr serverVersion\nquit\n" | nc localhost 7072
	echo -en "attr global serverVersion 0.01\nquit\n" | nc localhost 7072 #https://forum.fhem.de/index.php/topic,66616.0.html
	# save all and restart fhem to load yeelight module
	echo -en "save\nquit\n" | nc localhost 7072
	echo -en "shutdown restart\nquit\n" | nc localhost 7072
fi



#version 0.02
if sudo grep -Po "serverVersion \K\d+\.*\d*" /opt/fhem/fhem.cfg | grep -q  "0.01"; then
 echo  "update 0.05"
 echo -en "save\nquit\n" | nc localhost 7072
# sudo sed 's/.*attr global serverVersion.*/attr global serverVersion 0.02/' /opt/fhem/fhem.cfg
else
 echo  "no update"

fi














