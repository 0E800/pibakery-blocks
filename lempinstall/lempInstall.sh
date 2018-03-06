#!/bin/bash
apt-get update -qq
sleep 10
DEBIAN_FRONTEND=noninteractive apt-get -y install pwgen php7.0-mysql php7.0-common php7.0 php7.0-gd php7.0-xml php7.0-mbstring php7.0-curl -qq
sleep 10
DEBIAN_FRONTEND=noninteractive apt-get -y remove --purge apache2*
sleep 10
DEBIAN_FRONTEND=noninteractive apt-get -y install nginx-full mysql-server
sleep 10
