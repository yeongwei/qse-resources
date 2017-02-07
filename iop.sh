#!/bin/bash

thisScript=$0
mode=$1
shift
services=$@
validModes=("start" "stop" "restart" "status" "help" "h")
validServices=("ZOOKEEPER" "KAFKA" "HDFS" "YARN")

##############################################
##Define Functions
##############################################

missing_arg_check() {
  if [ -z "$1" ]
  then
    echo "Error: Missing arguments. Abort ${thisScript} run."
    echo ""
    $thisScript "help"
    exit 1
  fi
}

validate_service_name() {
  for i in ${validServices[@]}
  do
    if [ "$i" = "$1" ]
    then
      return
    fi
  done
  echo "Error: Invalid service ${1}. Abort ${thisScript} run."
  echo ""
  $thisScript "help"
  exit 1
}

##############################################
##Validate Arguments
##############################################

missing_arg_check $mode

if [ "${mode^^}" = "H" ] || [ "${mode^^}" = "HELP" ]
then
  IFS='|';echo "Usage: ${thisScript} {${validModes[*]}} {all|<service_name>}";IFS=$' \t\n'
  #echo "Usage: ${thisScript} {start|stop|restart|status|help|h} {all|<service_name>}"
  IFS='|';echo "service_name: {${validServices[*]}}";IFS=$' \t\n'
  echo ""
  echo "Example: "
  echo "  1) ${thisScript} start ZOOKEEPER"
  echo "  2) ${thisScript} start all    #Currently this will start all services in the following sequence: ZOOKEEPER, KAFKA, HDFS and YARN"
  echo "  3) ${thisScript} stop ZOOKEEPER"
  echo "  4) ${thisScript} stop all"
  echo "  5) ${thisScript} restart KAFKA"
  echo "  6) ${thisScript} restart all"
  echo "  7) ${thisScript} status HDFS"
  echo "  8) ${thisScript} status all"
  echo ""
  exit 1
fi

missing_arg_check $services

if [ "$services" = "all" ]
then
  services="${validServices[*]}"
else
  for service in $services; do
    validate_service_name "$service"
  done
fi

##############################################
##Apply mode
##############################################

PASSWORD=admin
CLUSTER_NAME=npi
MGMT1=sherpa

case "${mode}"
in
  start)
    for service in $services; do
      curl --silent -u admin:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start '"$service"' via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/$service
    done
  ;;

  stop)
    for service in $services; do
      curl --silent -u admin:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop '"$service"' via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/$service
    done
  ;;

  status)
    for service in $services; do
      echo "$service status: $(curl --silent -u admin:$PASSWORD -H 'X-Requested-By: ambari' -X GET http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/$service | grep \"state\" | awk '{gsub(/"/, "", $0); print $3}')"
    done
  ;;

  restart)
    count=0
    for service in $services; do
      curl --silent -u admin:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop '"$service"' via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/$service
      count=$((30+$count))
    done

    #Delay up to 120seconds (30 seconds per service) to allow all services to stop completely prior starting all again
    sleep $count

    for service in $services; do
      curl --silent -u admin:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start '"$service"' via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/$service
    done
  ;;

  *)
    echo "Error: Invalid mode ${mode}. Abort ${thisScript} run."
    echo ""
    $thisScript "help"
  ;;
esac
