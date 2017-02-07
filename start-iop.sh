#!/bin/bash

containerName=$1
iopDir="/usr/iop"

if [ ! -d "$iopDir" ]
then
  echo "ERROR: $iopDir does not exist! Run prep-iop.sh to pre-condition VM prior running $0. $0 run aborted."
  exit 1
fi

if [ -z "$containerName" ]
then
  containerName="iop-m"
fi

##############################################
##Start Ambari docker container
##############################################

echo "Starting Ambari docker container..."

docker run -itdP -p 8080:8080 -p 8670:8670 -p 8440:8440 \
    -p 8441:8441 -p 50010:50010 -p 50020:50020  -p 50070:50070 \
    -p 8188:8188 -p 8190:8190 -p 10200:10200 -p 8020:8020 \
    -p 50075:50075 -p 60010:60010 -p 60020:60020 -p 10000:10000 \
    -p 8088:8088 -p 50060:50060 -p 8032:8032 -p 2022:22 -p 80:80 \
    --privileged=true --net=host \
    --ulimit nproc=65535 --ulimit nofile=65535 --ulimit core=65535 \
    --cap-add audit_write --cap-add setgid --cap-add setuid --pid=host\
    $OPTS --name "$containerName" iop-mservices
docker exec "$containerName" /bin/bash -c "ulimit -c unlimited"

##############################################
##Copy JARs into iopDir
##############################################

echo "Copying JARs into ${iopDir}..."

docker exec $containerName bash -c "cd $iopDir; \
  tar -chf hadoop-client_client.tar ./current/hadoop-client/client; \
  tar -chf kafka-broker_libs.tar ./current/kafka-broker/libs; \
  tar -chf spark-client.tar ./4.1.0.0/spark-client"

libTars=('hadoop-client_client' 'kafka-broker_libs' 'spark-client')

for i in ${libTars[@]}; do
  docker cp ${containerName}:${iopDir}/${i}.tar ${iopDir}/.
  tar -xf $iopDir/${i}.tar -C $iopDir
  docker exec $containerName bash -c "rm -f $iopDir/${i}.tar"
  rm -f $iopDir/${i}.tar
done

#rename spark-client for standardisation

rm -rf $iopDir/current/spark-client
mv $iopDir/4.1.0.0/spark-client $iopDir/current/.
rm -rf $iopDir/4.1.0.0

#copy individual files

mkdir -p ${iopDir}/current/hadoop-yarn-client
mkdir -p ${iopDir}/current/spark-client/lib
mkdir -p ${iopDir}/current/zookeeper-client/lib

docker cp ${containerName}:${iopDir}/current/spark-client/lib/spark-assembly-1.6.0-hadoop2.6.0.jar ${iopDir}/current/spark-client/lib/.
docker cp ${containerName}:${iopDir}/current/zookeeper-client/lib/jline-0.9.94.jar ${iopDir}/current/zookeeper-client/lib/.
docker cp ${containerName}:${iopDir}/current/zookeeper-client/zookeeper-3.4.6_IBM_3.jar ${iopDir}/current/zookeeper-client/.
docker cp ${containerName}:${iopDir}/current/zookeeper-client/zookeeper.jar ${iopDir}/current/zookeeper-client/.
docker cp ${containerName}:${iopDir}/current/hadoop-yarn-client/hadoop-yarn-server-web-proxy-2.7.1-IBM-11.jar $iopDir/current/hadoop-yarn-client/.
docker cp ${containerName}:${iopDir}/current/hadoop-yarn-client/hadoop-yarn-server-web-proxy.jar $iopDir/current/hadoop-yarn-client/.

#sleep for a 30 seconds to allow ambari agent to complete startup in order to use REST API
sleep 30

##############################################
##Download and copy service client config into iopDir
##############################################

echo "Downloading and copying service client config into ${iopDir}..."

PASSWORD=admin
CLUSTER_NAME=npi
MGMT1=sherpa
services=('hdfs' 'yarn' 'spark')

for service in ${services[@]}; do
  curl --silent -o $iopDir/${service}_config.tar -u admin:$PASSWORD -H 'X-Requested-By: ambari' -X GET http://$MGMT1:8080/api/v1/clusters/$CLUSTER_NAME/services/${service^^}/components/${service^^}_CLIENT?format=client_config_tar
  mkdir -p ${iopDir}/current/${service}_config
  tar -xf $iopDir/${service}_config.tar -C $iopDir/current/${service}_config
  rm -f $iopDir/${service}_config.tar
done

echo "Done."
