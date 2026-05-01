```bash
sudo systemctl status kafka
```
```bash
sudo netstat -tlnp | grep 9092
```

```bash
# Создаем топик для демо (если еще не создан)
/opt/kafka/bin/kafka-topics.sh --create \
  --topic my-test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Проверяем список топиков
/opt/kafka/bin/kafka-topics.sh --list \
  --bootstrap-server localhost:9092
```

```bash
rebar3 shell
```
```bash
brod:start_producer(my_kafka_client, <<"my-test-topic">>, []).
```

```bash
supervisor:which_children(kafka_demo_sup).
```

```bash
application:get_key(brod, vsn).
```

```bash
brod:module_info(exports).
```

```bash
Exports = brod:module_info(exports),
lists:filter(fun({F,_}) -> lists:prefix("get_", atom_to_list(F)) end, Exports).
```


```bash
brod:get_consumer(my_kafka_client, <<"my-test-topic">>, 0).
```

```bash
brod:get_producer(my_kafka_client, <<"my-test-topic">>, 0).
```



```bash
[ brod:get_consumer(my_kafka_client, <<"my-test-topic">>, P) || P <- [0, 1, 2] ].
```