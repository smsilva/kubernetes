# Apache Kafka get started

## Install scripts

### Check

```bash
which kafka-topics.sh
```

### Download

https://kafka.apache.org/downloads


```bash
wget https://downloads.apache.org/kafka/3.7.0/kafka_2.13-3.7.0.tgz
```

### Configure PATH

```bash
export PATH=${PATH}:KAFKA_BIN_PATH_HERE
```

## Apache Kafka Quickstart

https://kafka.apache.org/quickstart


### Pull Docker Image

```bash
docker pull apache/kafka:3.7.0
```

### Start a Single Node Kafka Cluster using Docker

```bash
docker run \
  --rm \
  --name kafka \
  --hostname kafka \
  --network bridge \
  --publish 9092:9092 \
  apache/kafka:3.7.0
```

### Create Topics

```bash
kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic "events-inbound" \
  --partitions 3
```

### Describe Topic

```bash
kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic "events-inbound"
```

### Console Producer

```bash
kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic "events-inbound" \
  --batch-size 1
```

### Console Consumer

```bash
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic "events-inbound" \
  --group "console" \
  --from-beginning
```

### Describe Consumer Group

```bash
kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group "console" \
  --offsets
```
