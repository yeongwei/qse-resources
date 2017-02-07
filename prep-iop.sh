#!/bin/bash

dockerDir="/var/lib/docker"
localIopdir="/usr/iop"

if [ ! -d "$dockerDir" ] 
then
  echo "$dockerDir does not exist! abort run."
  exit 1
fi
chmod 755 $dockerDir

if [ ! -d "$localIopdir" ]
then
  mkdir $localIopdir
  chmod 777 $localIopdir
fi 
