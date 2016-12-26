#!/bin/bash

PROJECT='sample.local'
APPNAME='sample_container'
XDEBUG_HOST='127.0.0.1'

ENDC=`tput setaf 7`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`

if [ -n "$1" ]; then
	PROJECT=$1
else
	exit 0
fi

if [ -n "$2" ]; then
	APPNAME=$2
else
	exit 0	
fi

if [ -n "$3" ]; then
	ROOT_DIR=$3
else
	exit 0	
fi

echo $YELLOW "Start docker services" $ENDC

WPROJECT='www.'$PROJECT
XDEBUG_HOST=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

if [ -s 'docker-compose.yml' ]; then
	rm docker-compose.yml
fi	

cp docker-compose.yaml.sample docker-compose.yml

sed -i "s/container_name_variable/${APPNAME}/g" docker-compose.yml
sed -i "s|root_dir|${ROOT_DIR}|g" docker-compose.yml
sed -i "s/xdebug_remote_host/${XDEBUG_HOST}/g" docker-compose.yml

docker-compose up -d

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


	WCONDITION="grep -q '"$WPROJECT"' /etc/hosts"
	if eval $WCONDITION; then
		WCMD="sudo sed -i -r \"s/^ *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+( +"$WPROJECT")/"$IP" "$WPROJECT"/\" /etc/hosts";
	else
		WCMD="sudo sed -i '\$a\\\\n# Added automatically by run.sh\n"$IP" "$WPROJECT"\n' /etc/hosts";
	fi
	
	echo Nginx server image loaded at http://$IP [Internal IP]
	
	eval $CMD
	if [ "$?" -ne 0 ]; then
		echo $RED ERROR: Could not update $PROJECT to hosts file. $ENDC
		exit 1
	fi

	eval $WCMD
	if [ "$?" -ne 0 ]; then
		echo $RED ERROR: Could not update $WPROJECT to hosts file. $ENDC
		exit 1
	fi

	echo $GREEN Go to http://$PROJECT or http://$WPROJECT $ENDC
}

nginx_conf