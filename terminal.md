```bash
# Терминал 2: Отправка сообщений
/opt/kafka/bin/kafka-console-producer.sh \
  --topic my-test-topic \
  --bootstrap-server localhost:9092

> Hello World
> Test 1
> Test 2
```

```bash
/opt/kafka/bin/kafka-topics.sh --create \
  --topic my-test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Проверьте, что топик создан
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
```

```bash
/opt/kafka/bin/kafka-console-producer.sh \
  --topic my-test-topic \
  --bootstrap-server localhost:9092
```