#!/bin/bash

export CLUSTER_NAME=npi
export MGMT1=sherpavm
source functions
registerBlueprint $MGMT1 qse-1-nodes-42 blueprint.json
installCluster
checkProgress
checkFinalStatus
