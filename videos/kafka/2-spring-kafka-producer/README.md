# Spring Kafka Producer

https://start.spring.io

## Dependencies

- Spring Boot Actuator
- Spring Integration
- Spring for Apache Kafka
- Spring Web

## application.yaml

```yaml
spring:
  application:
    name: wasp-producer

  kafka:
    bootstrap-servers: localhost:9092

    producer:
      topic: ${SPRING_KAFKA_PRODUCER_TOPIC:events-inbound}
```

## First run

```shell
mvn spring-boot:run
```

## Start Apache Kafka single node using docker

```bash
docker run \
  --rm \
  --detach \
  --name kafka \
  --hostname kafka \
  --network bridge \
  --publish 9092:9092 \
  apache/kafka:3.7.0
```

## Create Topic

```bash
kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic "events-inbound" \
  --partitions 3
```

## Message Driven Channel Adapter

https://docs.spring.io/spring-integration/reference/kafka.html#kafka-inbound

### DTO: Data

```java
public class Data {

    private String id;
    private String name;

    public Data() {
        int randomId = new Random().nextInt(1000);
        this.setId(String.valueOf(randomId));
        this.setName("Name #" + randomId);
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

}
```

### Configuration: ProducerFactory and MessageHandler


```java
@Configuration
@ConditionalOnProperty(prefix = "spring.kafka", name = "enabled")
public class KafkaProducerConfig {

    @Bean
    public ProducerFactory<String, Data> kafkaProducerFactory(KafkaProperties properties) {
        Map<String, Object> producerProperties = properties.buildProducerProperties(null);
        producerProperties.put(ProducerConfig.LINGER_MS_CONFIG, 1);
        producerProperties.put(ProducerConfig.PARTITIONER_CLASS_CONFIG, RoundRobinPartitioner.class);
        return new DefaultKafkaProducerFactory<>(producerProperties, new StringSerializer(), new JsonSerializer<>());
    }

    @Bean
    public KafkaTemplate<String, Data> kafkaTemplate(ProducerFactory<String, Data> producerFactory) {
        return new KafkaTemplate<>(producerFactory);
    }

    @Bean
    public MessageHandler kafkaProducerHandler(
            KafkaTemplate<String, Data> kafkaTemplate,
            @Value("${spring.kafka.producer.topic}") String topic,
            @Value("${spring.kafka.producer.message-key}") String messageKey) {
        KafkaProducerMessageHandler<String, Data> handler = new KafkaProducerMessageHandler<>(kafkaTemplate);
        handler.setTopicExpression(new LiteralExpression(topic));
        handler.setMessageKeyExpression(new LiteralExpression(messageKey));
        return handler;
    }

}
```

### Producer Service

```java
@Component
public class KafkaProducerService {

    private static final Logger log = LoggerFactory.getLogger(KafkaProducerService.class);

    private final MessageHandler kafkaProducerHandler;

    public KafkaProducerService(MessageHandler kafkaProducerHandler) {
        this.kafkaProducerHandler = kafkaProducerHandler;
    }

    public void send(Data data) throws MessagingException {
        log.info("event.id: {} event.name: {}", data.getId(), data.getName());

        Message<Data> message = new GenericMessage<>(data);
        kafkaProducerHandler.handleMessage(message);
    }

}
```

### Controller

```java
@RestController
@RequestMapping("/events")
public class KafkaProducerController {

    private final KafkaProducerService kafkaProducerService;

    public KafkaProducerController(KafkaProducerService kafkaProducer) {
        this.kafkaProducerService = kafkaProducer;
    }

    @PostMapping("/send")
    public ResponseEntity<Data> sendEvent() {
        Data data = new Data();

        kafkaProducerService.send(data);

        return ResponseEntity
                .ok()
                .body(data);
    }

}
```

### First test with Serializer error

```shell
curl --request POST http://localhost:8080/events/send
```

### Test

```shell
curl --request POST http://localhost:8080/events/send
```

## Console Consumer

```bash
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic "events-inbound" \
  --group "console" \
  --from-beginning
```

## Native Image with GraalVM

### Install JDK 22 with GraalVM

```shell
sdk install java 22-graalce
```

### Add pom.xml plugin for GraalVM

```xml
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
</plugin>
```

### Compile

https://docs.spring.io/spring-boot/docs/current/reference/html/native-image.html#native-image.developing-your-first-application.native-build-tools.maven

```shell
mvn -P native native:compile
```

### Dockerfile

```dockerfile
FROM ubuntu:22.04

RUN groupadd -r spring && \
    useradd -r -g spring -m -s /bin/bash spring

USER spring:spring

COPY target/wasp-producer /app/entrypoint

CMD ["/app/entrypoint"]
```
