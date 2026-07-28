# Kafka Setup

> [!NOTE]
> #Kafka #DataStreaming #MessageBroker #Infrastructure #DockerCompose


## 1. Description

Apache Kafka is a distributed log/message bus for high-throughput event streaming — producers write topics, consumers process them asynchronously.

## 2. Deployment

Add and start the stack in Portainer.

## 3. Zookeeper (Optional)

> [!NOTE]
> Zookeeper is technically not required for Kafka to run.

   ```yml
   services:
     zookeeper:
       image: 'arm64v8/zookeeper:latest'
       container_name: zookeeper
       ports:
         - '2181:2181'
       environment:
         - ALLOW_ANONYMOUS_LOGIN=yes
       volumes:
         - 'zookeeper_data:/bitnami/zookeeper'
           
   volumes:
     zookeeper_data:
       driver: local
   ```
