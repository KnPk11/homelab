# Kafka Setup

> [!NOTE]
> **Tags:** #kafka #data_streaming #message_broker #infrastructure #docker_compose

## 1. Deployment

Add and start the stack in Portainer.

## 2. Zookeeper (Optional)

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
