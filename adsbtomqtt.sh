#!/bin/sh
#
# Post ADBS Receiver data to MQTT

# Configuration variables
#
RPINAME=`uname -n`

# For a list of free public servers, check https://github.com/mqtt/mqtt.github.io/wiki/public_brokers
# MQTT broker
MQTTHOST="iot.eclipse.org"

# Change this to become something unique, so that you get your own topic path
#
MQTTPREFIX="yourname"

# Descriptive topic, can be any string
#
TOPIC="ads-b"

##########################
#       script
##########################
tty -s
if [ $? = 1 ]; then
    sleep 30
fi

nowold=0
messagesold=0

if pgrep -f /usr/bin/dump1090-mutability > /dev/null; then
   VER="dump1090"
   else
   VER="dump1090-fa"
fi

while true
   do
      if pgrep dump1090 > /dev/null; then
          NOW=`wget -q -O - "localhost/$VER/data/aircraft.json" | jq '.now' | awk '{print int($0)}'`
          MESSAGES=`wget -q -O - "localhost/$VER/data/aircraft.json" | jq '.messages'`
          nowdelta=`expr $NOW - $nowold`
          messagesdelta=`expr $MESSAGES - $messagesold`
          RATE=`echo "$messagesdelta $nowdelta /p" | dc`
          AC_POS=`wget -q -O - "localhost/$VER/data/aircraft.json" | jq '[.aircraft[] | select(.seen_pos)] | length'`
          AC_TOT=`wget -q -O - "localhost/$VER/data/aircraft.json" | jq '[.aircraft[] | select(.seen < 60)] | length'`
          DUMP=`echo "Aircraft:$AC_TOT\nPosition:$AC_POS\nMsg/s:$RATE"`
          #echo $DUMP
          nowold=$NOW
          messagesold=$MESSAGES
          SCAT="off"
          if pgrep socat > /dev/null; then
             SCAT="run"
          fi
          MLAT="off"
          if pgrep mlat-client > /dev/null; then
             CONN=`ss -r -t state established | grep "adsbexchange.com:31090" | wc -l`
             if [ "$CONN" -gt 0 ]; then
                MLAT="run\nconnected"
                else
                MLAT="run\nstand-by"
             fi
          fi
          ADSBX=`echo "Socat:$SCAT\nMlat:$MLAT"`
          FR24="0"
          if pgrep fr24feed > /dev/null; then
             FR24="1"
          fi
          FA="0"
          if pgrep -f /usr/bin/piaware > /dev/null; then
             if pgrep -f /usr/lib/piaware/helpers/faup1090 > /dev/null; then
                if pgrep -f /usr/lib/piaware/helpers/fa-mlat-client > /dev/null; then
                   FA="1"
                fi
             fi
          fi
          PF="0"
          if pgrep pfclient > /dev/null; then
             PF="1"
          fi
          RBOX="0"
          if pgrep rbfeeder > /dev/null; then
             RBOX="1"
          fi
          OSKY="0"
          if pgrep openskyd-dump1090 > /dev/null; then
             OSKY="1"
          fi
          /usr/bin/mosquitto_pub -h $MQTTHOST -t "$MQTTPREFIX/$RPINAME/$TOPIC" -m "{ \"dump\" : \"$DUMP\", \"adsbx\" : \"$ADSBX\", \"fr24\" : \"$FR24\", \"fa\" : \"$FA\", \"pf\" : \"$PF\", \"rbox\" : \"$RBOX\", \"osky\" : \"$OSKY\" }"
      fi
      sleep 5
 done