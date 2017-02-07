#!/bin/bash
#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2010, 2015
# The source code for this program is not published or 
# otherwise divested of its trade secrets, irrespective of 
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

usage() {
  echo
  echo "$0 [file] [option] - Deploy BigInsights Quick Start Edition"
  echo "  -m  Ambari only installation (default)"
  echo "  -i  Install IOP stack"
  echo "  -v  Install IOP and Value Add stack"
  echo
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
elif [ ! -e $1 ]; then
  echo "$1 file does not exist..."
  usage
  exit 1
elif [[ ( ! -s $1 ) || ( -z "`cat $1`" ) ]]; then
  echo "$1 file is empty..."
  usage
  exit 1
fi

HOST_FILE=$1
HOSTS=`cat $1`
MGMT_HOST=`cat $1 | head -n 1`
MGMT_IP=`getent ahostsv4 ${MGMT_HOST} | awk '{ print $1 }' | head -n1`
DEPLOY_OPTS="$2"
OPTS=""
CONT_HOSTS=""
file1="/tmp/run.sh"
file2="/tmp/iop-m.tar"
CLUSTER_NAME="demo"
IMG_NAME="iop-m.tar"
DL_CMD="cd /tmp; wget -nv -N 'https://ibm-open-platform.ibm.com/images/docker/4/x86_64/4.1.0.2-1/${IMG_NAME}'"

bin=$1
basedir=`dirname $bin`

. $basedir/functions

prereqCheck $HOST_FILE

echo "Checking if the required files exists on all nodes"

errorFlag=0
for HOST in ${HOSTS}; do
  echo -e "\nDownloading Docker image on ${HOST}"
  ssh $HOST $DL_CMD
  if [[ $? != 0 ]]; then
    echo -e "image not found!\nExiting the deployment."
    exit 1
  fi
  scp run.sh ${HOST}:/tmp
done

echo -e "\nManagement Host: ${MGMT_HOST}"
ssh ${MGMT_HOST} /tmp/run.sh $OPTS

result=-1
while [ "$result" != "0" ]; do
  echo "Waiting for management node to start.."
  curl -s http://${MGMT_HOST}/hosts >/dev/null
  result=$?
  sleep 5
done

for HOST in ${HOSTS}; do
  if [[ ! ${HOST} == ${MGMT_HOST} ]]; then
    echo -e "\nHost: ${HOST}"
    ssh ${HOST} /tmp/run.sh -e MGMT_HOST=${MGMT_IP}
  fi
done

INSTALL_IOP="false"
INSTALL_VA="false"

if [ "$DEPLOY_OPTS" == "-i" ]; then
  INSTALL_IOP="true"
  INSTALL_VA="false"
fi

if [ "$DEPLOY_OPTS" == "-v" ]; then
  INSTALL_IOP="false"
  INSTALL_VA="true"
fi

if [ "$INSTALL_IOP" == "false" -a "$INSTALL_VA" == "false" ]; then
  echo -e "While going through cluster configuration, in step 2 [Install Options], provide follwing list of hostnames and choose \"Perform manual registration on hosts and do not use SSH\" for ambari-agent:"
  cat $1
fi

if [ "$INSTALL_IOP" == "true" ]; then
  nodeArray=(${HOSTS})
  nodeSize=${#nodeArray[@]}
  case $nodeSize in
    1) #echo "Single node IOP"
       generateBlueprint $HOST_FILE template_single_blueprint.json iop
       registerBlueprint $MGMT1 qse-1-nodes-41 blueprint.json
       generateHostmapping $HOST_FILE
       installCluster
       checkProgress
       checkFinalStatus ;;
    5) #echo "Five node IOP"
       generateBlueprint $HOST_FILE template_blueprint.json iop
       registerBlueprint $MGMT1 qse-5-nodes-41 blueprint.json
       generateHostmapping $HOST_FILE
       installCluster
       checkProgress
       checkFinalStatus ;;
    *) echo "Invalid Number of hosts for blueprint installation!" ;;
  esac 

fi

if [ "$INSTALL_VA" == "true" ]; then
  nodeArray=(${HOSTS})
  nodeSize=${#nodeArray[@]}
  case $nodeSize in
    1) #echo "Single node valueadd"
       generateBlueprint $HOST_FILE template_single_valueadd.json valueadd
       registerBlueprint $MGMT1 qse-1-nodes-41 blueprint.json
       generateHostmapping $HOST_FILE
       installCluster
       checkProgress
       checkFinalStatus 
       VERSION="version`date +%s`"
       prepareBigSql "BIGSQL" "$VERSION"
       callInstall "BIGSQL"
       if [[ $containError != true ]]; then 
         knoxSetup
         restartStaleServices $MGMT1 $CLUSTER_NAME
       fi ;;
    5) #echo "5 nodes valueadd"
       generateBlueprint $HOST_FILE template_valueadd.json valueadd
       registerBlueprint $MGMT1 qse-5-nodes-41 blueprint.json
       generateHostmapping $HOST_FILE
       installCluster
       checkProgress
       checkFinalStatus
       if [[ $containError != true ]]; then 
         knoxSetup
         restartStaleServices $MGMT1 $CLUSTER_NAME
       fi ;;
    *) echo "Invalid Number of hosts for blueprint installation!" ;;
  esac 
fi

startAllServices

echo -e "\nPoint your browser to ambari-server at: http://${MGMT_IP}:8080/"
if [ "$INSTALL_VA" == "true" ]; then
  echo -e "\nBigInsights Home can be accessed at: https://${MGMT_IP}:8443/gateway/default/BigInsightsWeb/index.html"
fi
echo "Would you like to send anonymous data to help IBM improve the product? (Y/n)"
read ANSWER

if [ "$ANSWER" == "" -o "$ANSWER" == "y" ]; then
  echo -n "Sending.."
  docker exec iop-m heartbeat.py
  echo "done."
fi

echo "Thank you for choosing IBM BigInsights Quickstart Edition."
