#!/bin/bash

PROJECT='wap.local'
WWWPROJECT='www.wap.local'
APPNAME='magento2_nginx'
XDEBUG_HOST='192.168.11.15'

ENDC=`tput setaf 7`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`

echo $YELLOW "Start docker services" $ENDC
docker-compose up -d

if [ -n "$1" ]; then
	PROJECT=$1
fi

init_conf() {
	sed -i "s/xdebug_remote_host/${XDEBUG_HOST}/g" docker-compose.yml
}

nginx_conf() {
	NGINX_CONTAINER_ID=$(docker ps | grep ${APPNAME} | awk '{print $1}')
	if [ -z "$NGINX_CONTAINER_ID" ]; then
		echo $RED ERROR: Container \"$PROJECT\" could not be started. $ENDC
		exit 1
	fi

	IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $NGINX_CONTAINER_ID)
	if [ -z "$IP" ]; then
		echo $RED ERROR: Could not find the IP address of container \"$PROJECT\". $ENDC
		exit 1
	fi

	echo Attempting to update hosts file [Require root password]

	CONDITION="grep -q '"$PROJECT"' /etc/hosts"
	if eval $CONDITION; then
		CMD="sudo sed -i -r \"s/^ *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+( +"$PROJECT")/"$IP" "$PROJECT"/\" /etc/hosts";
	else
		CMD="sudo sed -i '\$a\\\\n# Added automatically by run.sh\n"$IP" "$PROJECT"\n' /etc/hosts";
	fi


	CONDITION="grep -q '"$WWWPROJECT"' /etc/hosts"
	if eval $CONDITION; then
		CMD="sudo sed -i -r \"s/^ *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+( +"$WWWPROJECT")/"$IP" "$WWWPROJECT"/\" /etc/hosts";
	else
		CMD="sudo sed -i '\$a\\\\n# Added automatically by run.sh\n"$IP" "$WWWPROJECT"\n' /etc/hosts";
	fi
	
	echo Nginx server image loaded at http://$IP [Internal IP]
	
	eval $CMD
	if [ "$?" -ne 0 ]; then
		echo $RED ERROR: Could not update $PROJECT to hosts file. $ENDC
		exit 1
	fi

	echo $GREEN Go to http://$PROJECT $ENDC
}

init_conf
nginx_conf