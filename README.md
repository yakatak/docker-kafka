Kafka Docker image configured to dynamically and atomically allocate itself a broker id through ZooKeeper.  It expects a comma delimited list of ZooKeeper servers via the `ZOOKEEPER_SERVERS` environment variable and and an optional root path within ZooKeeper were to store it's state via `ZOOKEEPER_ROOT` (it defaults to `/kafka`).

It can be executed in Kuebernetes using a replication controller using a config like:

```
apiVersion: v1
kind: Service
metadata:
  name: kafka
spec:
  clusterIP: None
  ports:
    - name: kafka
      port: 9092
      protocol: TCP
    - name: jmx
      port: 7203
      protocol: TCP
  selector:
    app: kafka
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: kafka
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: kafka
    spec:
      volumes:
        - name: kafka
          emptyDir: {}
      containers:
        - name: server
          image: quay.io/xeizmendi/docker-kafka:latest
          env:
            - name: ZOOKEEPER_SERVERS
              value: zookeeper:2181
            - name: ZOOKEEPER_ROOT
              value: /kafka
            #- name: KAFKA_HEAP_OPTS
            #  value: "-Xms1g -Xmx1g"
            #- name: KAFKA_OFFSET_REPLICATION_FACTOR
            #  value: "3"
            #- name: KAFKA_AUTO_CREATE_TOPICS
            #  value: "false"
          ports:
            - containerPort: 9092
              name: broker
              protocol: TCP
            - containerPort: 7203
              name: jmx
              protocol: TCP
          volumeMounts:
            - mountPath: /kafka/persistent
              name: kafka
```