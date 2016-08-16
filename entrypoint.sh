#!/bin/bash

# Only allocate a broker id and configure the system the first time this container starts.
# A Kubernetes volume mount will preserve the config if the container dies and is restarted
# in the same node.
if [ ! -d /kafka/persistent/config ]; then
  mkdir -p /kafka/persistent/config
fi

if [ ! -d /kafka/persistent/logs ]; then
  mkdir -p /kafka/persistent/logs
fi

if [ ! -d /kafka/persistent/data ]; then
  mkdir -p /kafka/persistent/data
fi

ln -s /kafka/persistent/config /kafka/config
ln -s /kafka/persistent/logs /kafka/logs
ln -s /kafka/persistent/data /kafka/data

if [ ! -f /kafka/config/server.properties ]; then
	# Create a ZK connection string for the servers and the root.
	ZOOKEEPER_CONNECT=$ZOOKEEPER_SERVERS${ZOOKEEPER_ROOT:=/kafka}
	KAFKA_OFFSET_REPLICATION_FACTOR=${KAFKA_OFFSET_REPLICATION_FACTOR:=3}
  KAFKA_AUTO_CREATE_TOPICS=${KAFKA_AUTO_CREATE_TOPICS:=false}

	echo "Using ZK at ${ZOOKEEPER_CONNECT}"

	# Create the ZK root if it doesn't already exist.
	echo create "$ZOOKEEPER_ROOT" 0 | /kafka/bin/zookeeper-shell.sh $ZOOKEEPER_SERVERS &> /dev/null

	if [ -z $BROKER_ID ]; then
		# Create node to use for id allocation.
		echo create /allocate_kafka_id 0 | /kafka/bin/zookeeper-shell.sh $ZOOKEEPER_CONNECT &> /dev/null

		# Allocate an id by writing to a node and retriving its version number.
		BROKER_ID=`echo set /allocate_kafka_id 0 | /kafka/bin/zookeeper-shell.sh $ZOOKEEPER_CONNECT 2>&1 | grep dataVersion | cut -d' ' -f 3`
		echo "Allocated broker id ${BROKER_ID}."
	else
		echo "Using broker id ${BROKER_ID}."
	fi

	# Create the config file.
	sed -e "s|\${BROKER_ID}|$BROKER_ID|g" \
			-e "s|\${ADVERTISED_HOST_NAME}|$ADVERTISED_HOST_NAME|g " \
			-e "s|\${KAFKA_OFFSET_REPLICATION_FACTOR}|$KAFKA_OFFSET_REPLICATION_FACTOR|g " \
			-e "s|\${KAFKA_AUTO_CREATE_TOPICS}|$KAFKA_AUTO_CREATE_TOPICS|g " \
			-e "s|\${ZOOKEEPER_CONNECT}|$ZOOKEEPER_CONNECT|g" /kafka/templates/server.properties.template > /kafka/config/server.properties

	cp /kafka/templates/log4j.properties /kafka/templates/tools-log4j.properties /kafka/config
fi

cd /kafka
exec "$@"
