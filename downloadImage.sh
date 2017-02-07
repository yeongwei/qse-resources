#!/bin/bash
#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2010, 2015
# The source code for this program is not published or 
# otherwise divested of its trade secrets, irrespective of 
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

# This script copy the docker image and the deployment scripts to your cluster of machines

usage() {
  echo "$0 [file/iop/qse] - where [file] contains a list of hostnames in your cluster, and iop/qse refers to downloading of respective single node docker image."
}

downloadIOP() {
  echo "Downloading IBM Open Platform for Hadoop"
  curl -LOk http://ibm-open-platform.ibm.com/repos/images/docker/IOP_v4100_201508.zip
  curl -LOk http://ibm-open-platform.ibm.com/repos/images/docker/IOP_v4100_readme.pdf
  echo "Refer to IOP_v4100_readme.pdf for usage instruction."
}

downloadQSE() {
  echo "Downloading IBM BigInsights Quick Start Edition"
  curl -LOk http://ibm-open-platform.ibm.com/repos/images/docker/BigInsights_QSE_v4100_201508.zip
  curl -LOk http://ibm-open-platform.ibm.com/repos/images/docker/BigInsights_QSE_v4100_readme.pdf
  echo "Refer to BigInsights_QSE_v4100_readme.pdf for usage instruction"
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
elif [ ! "iop" == "$1" ] && [ ! "qse" == "$1" ]; then
  if [ ! -e $1 ]; then
    usage
    exit 1
  fi
fi

if [ "$1" == "iop" ]; then
  downloadIOP
  exit 0
elif [ "$1" == "qse" ]; then
  downloadQSE
  exit 0
fi

HOSTS=`cat $1`
MGMT_HOST=`cat $1 | head -n 1`
MGMT_IP=`getent hosts ${MGMT_HOST} | awk '{ print $1 }'`
OPTS=""
CONT_HOSTS=""
IMG_NAME="iop-m.tar"
SCRIPT_NAME="run.sh"
deploycript=`dirname "$0"`
scripthome=`cd "$deploycript"; pwd`

echo -e "\nDownloading Docker image"
#wget -nv -N "https://ibm-open-platform.ibm.com/repos/images/docker/${IMG_NAME}"

echo "Checking if the $IMG_NAME exists in the current directory"
if [ -f "$scripthome/$IMG_NAME" ]; then
   echo "File $IMG_NAME exists" in $scripthome
else
   echo "The File $IMG_NAME does not exist in $scripthome"
   exit 1
fi

echo "Checking if the $SCRIPT_NAME exists in the current directory"
if [ -f "$scripthome/$SCRIPT_NAME" ]; then
   echo "File $SCRIPT_NAME exists" in $scripthome
else
   echo "The File $SCRIPT_NAME does not exist in $scripthome"
   exit 1
fi

echo -e "\nCopying files to management host (${MGMT_HOST})"
scp run.sh ${MGMT_HOST}:/tmp
scp iop-m.tar ${MGMT_HOST}:/tmp

for HOST in ${HOSTS}; do
  if [[ ! ${HOST} == ${MGMT_HOST} ]]; then
    echo -e "\nCopying files to host (${HOST})"
    scp run.sh ${HOST}:/tmp
    scp iop-m.tar ${HOST}:/tmp
  fi
done
