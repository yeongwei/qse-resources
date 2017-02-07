#!/bin/bash
#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2010, 2015
# The source code for this program is not published or 
# otherwise divested of its trade secrets, irrespective of 
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

DOCKER_INSTALLED=`rpm -qa |grep -q docker-engine && echo true`

if [ "z${DOCKER_INSTALLED}" != "ztrue" ]; then
  curl -sSL https://get.docker.com/ | sh
  service docker start
fi

#--ulimit nproc=12000 --ulimit core=`cat /proc/cpuinfo|grep processor|wc -l` \

OPTS="$@"

echo "Loading docker image"
docker load -i /tmp/iop-m.tar

#echo "$OPTS"

docker run -itdP -p 8080:8080 -p 8670:8670 -p 8440:8440 \
    -p 8441:8441 -p 50010:50010 -p 50020:50020  -p 50070:50070 \
    -p 8188:8188 -p 8190:8190 -p 10200:10200 -p 8020:8020 \
    -p 50075:50075 -p 60010:60010 -p 60020:60020 -p 10000:10000 \
    -p 8088:8088 -p 50060:50060 -p 8032:8032 -p 2022:22 -p 80:80 \
    --privileged=true --net=host \
    --ulimit nproc=65535 --ulimit nofile=65535 --ulimit core=65535 \
    $OPTS --name iop-m iop-m
docker exec iop-m /bin/bash -c "ulimit -c unlimited"
