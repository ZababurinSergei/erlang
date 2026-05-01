Отлично! Раз Kafka уже установлена локально, давайте запустим и проверим полную интеграцию.

## 1. Проверка статуса Kafka

```bash
# Проверка, запущена ли Kafka
sudo systemctl status kafka

# Если не запущена - запускаем
sudo systemctl start kafka

# Проверка портов
sudo netstat -tlnp | grep 9092
# или
ss -tlnp | grep 9092
```

## 2. Создание тестового топика

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

## 3. Настройка конфигурации

Редактируем `config/sys.config`, отключаем тестовый режим:

```bash
cd ~/kafka_demo
nano config/sys.config
```

Замените `{test_mode, true}` на `{test_mode, false}`:

```erlang
{kafka_demo, [
    {kafka_hosts, [{"localhost", 9092}]},
    {client_id, my_kafka_client},
    {topic, <<"my-test-topic">>},
    {consumer_group, <<"kafka-demo-group">>},
    {begin_offset, earliest},
    {test_mode, false}    %% <-- ИЗМЕНИТЬ НА false
]},
```

## 4. Запуск приложения

### Вариант A: Интерактивная консоль (рекомендуется для отладки)

```bash
rebar3 shell
```

В консоли Erlang:

```erlang
%% Запуск приложения
application:start(kafka_demo).

%% Должны увидеть:
%% Starting kafka_demo application...
%% kafka_stats_event handler added successfully
%% kafka_demo started with my_kafka_client
```

### Вариант B: Production релиз

```bash
# Пересобираем релиз с новой конфигурацией
rebar3 release

# Запускаем
_build/default/rel/kafka_demo_release/bin/kafka_demo_release console
```

## 5. Отправка тестовых сообщений в Kafka

### Терминал 1: Отправка сообщений (producer)

```bash
# Простой producer
/opt/kafka/bin/kafka-console-producer.sh \
  --topic my-test-topic \
  --bootstrap-server localhost:9092

# Вводим сообщения (каждое с новой строки):
> Hello from Kafka!
> Test message 1
> {“user”: “sergei”, “action”: “test”}
> Message with key:value
> Ctrl+C для выхода
```

### Терминал 2: Альтернативный способ - через Erlang

В консоли Erlang (где запущено приложение):

```erlang
%% Отправка через brod
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<"key1">>, <<"value1">>).
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 1, <<"key2">>, <<"value2">>).
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 2, <<"key3">>, <<"value3">>).

%% Пакетная отправка
lists:foreach(fun(I) ->
    brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, 
                      <<>>, list_to_binary("Message " ++ integer_to_list(I)))
end, lists:seq(1, 10)).
```

## 6. Проверка работы приложения

### Мониторинг в реальном времени

В консоли Erlang вы должны видеть:

```
--- Kafka Message ---
Partition: 0
Offset: 0
Key: key1
Value: value1
---------------------

--- Kafka Message ---
Partition: 1
Offset: 0
Key: key2
Value: value2
---------------------
```

### Проверка статистики

```erlang
%% Счетчик сообщений
kafka_gen_server:get_messages_count().
%% Должен вернуть {ok, N}

%% Полная статистика
kafka_gen_server:get_stats().
%% Вернет record с messages_received, last_offset и др.

%% Сброс статистики
kafka_gen_server:reset_stats().
```

### Проверка через sys

```erlang
%% Состояние gen_server
sys:get_status(kafka_gen_server).

%% Дерево супервизии
supervisor:which_children(kafka_demo_sup).

%% Event manager handlers
gen_event:which_handlers(kafka_event_manager).
%% Должен вернуть [kafka_stats_event]
```

## 7. Комплексный тест

Создайте тестовый скрипт:

```erlang
%% В консоли Erlang
%% Функция для отправки тестовых сообщений
send_test_messages() ->
    lists:foreach(fun(I) ->
        Message = list_to_binary("Test message " ++ integer_to_list(I)),
        case brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<>>, Message) of
            ok -> io:format("Sent message ~p~n", [I]);
            Error -> io:format("Error: ~p~n", [Error])
        end,
        timer:sleep(100)
    end, lists:seq(1, 20)).

%% Запуск
send_test_messages().

%% Проверка счетчика (должно быть 20)
kafka_gen_server:get_messages_count().
```

## 8. Просмотр логов

```bash
# В другом терминале смотрите логи
tail -f log/sasl-error.log

# Или логи приложения в консоли Erlang
logger:set_primary_config(level, debug).
```

## 9. Проверка всех OTP компонентов

```erlang
%% 1. Проверка событий
gen_event:notify(kafka_event_manager, {test_event, "manual"}).

%% 2. Проверка зарегистрированных процессов
registered().
%% Должен содержать: kafka_demo_sup, kafka_event_manager, kafka_gen_server

%% 3. Проверка distributed registration
global:whereis_name(kafka_demo_sup).

%% 4. Информация о brod клиенте
brod:get_client(my_kafka_client).
```

## 10. Ожидаемый вывод при успешном запуске

```
Starting kafka_demo application...
kafka_stats_event handler added successfully
kafka_demo started with my_kafka_client
[kafka_console_printer] Connected to Kafka
[kafka_console_printer] Subscribed to my-test-topic

--- Kafka Message ---
Partition: 0
Offset: 0
Key: <<>>
Value: Hello from Kafka!
---------------------

[STATS] Processed 1 messages
```

## Устранение неполадок

### Если сообщения не приходят:

```erlang
%% 1. Проверить подписку
application:get_env(kafka_demo, topic).
%% Должен вернуть {ok, <<"my-test-topic">>}

%% 2. Проверить consumer group
brod:get_consumer_group_subscriptions().

%% 3. Принудительно переподписаться
brod:unsubscribe(my_kafka_client, <<"my-test-topic">>, 0).
brod:subscribe(my_kafka_client, <<"my-test-topic">>, 0, self(), [{begin_offset, earliest}]).
```

### Если брокер не доступен:

```bash
# Проверка соединения
telnet localhost 9092

# Перезапуск Kafka
sudo systemctl restart kafka

# Проверка логов Kafka
sudo journalctl -u kafka -f
```

## Быстрый чек-лист успешного запуска

- [x] `sudo systemctl status kafka` → active (running)
- [x] Топик создан: `kafka-topics.sh --list` → виден `my-test-topic`
- [x] Приложение запущено: `application:which_applications()` → содержит `kafka_demo`
- [x] Consumer подписан: `kafka_console_printer` процесс запущен
- [x] Сообщения отправлены и получены
- [x] Счетчик увеличивается: `kafka_gen_server:get_messages_count()` > 0

После проверки остановите приложение:

```erlang
application:stop(kafka_demo).
%% или Ctrl+C дважды
```

Все готово для демонстрации! 🚀

Вариант 1: Создать топик с 3 партициями (рекомендуется для демо)
```bash
# В терминале
/opt/kafka/bin/kafka-topics.sh --delete --topic my-test-topic --bootstrap-server localhost:9092
/opt/kafka/bin/kafka-topics.sh --create \
  --topic my-test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```