# Kafka Demo on Erlang/OTP - Презентация

## 🎯 Демонстрация работы приложения с двумя консолями

### Архитектура демонстрации

```
┌─────────────────────────────────────────────────────────────┐
│                     Терминал 1 (Producer)                    │
│  /opt/kafka/bin/kafka-console-producer.sh                   │
│                                                              │
│  > Hello World                                              │
│  > Test Message 1                                           │
│  > Test Message 2                                           │
│  > ...                                                      │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────┐
│  Kafka Broker   │
│  localhost:9092 │
│  my-test-topic  │
└─────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                 Терминал 2 (Erlang Consumer)                 │
│                                                              │
│  === Kafka Message Set ===                                  │
│  Topic: <<"my-test-topic">>                                 │
│  Partition: 0                                               │
│  Message count: 1                                           │
│                                                              │
│  --- Message ---                                             │
│  Offset: 42                                                 │
│  Value: Hello World                                         │
│                                                              │
│  [STATS] Processed 42 messages                              │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Предварительная подготовка

### Шаг 1: Очистка и полная пересборка

```bash
# Терминал 1 (Основной)

# Полная очистка
pkill -f beam.smp
rm -rf ~/.cache/rebar3
rebar3 clean -a
rm -rf _build deps rebar.lock

# Сборка приложения
rebar3 compile
rebar3 release

# Запуск Erlang shell
rebar3 shell
```

### Шаг 2: Создание тестового скрипта для автоматической отправки

Создайте файл `send_messages.sh`:

```bash
#!/bin/bash
# Автоматическая отправка сообщений в Kafka

TOPIC="my-test-topic"
BOOTSTRAP="localhost:9092"

echo "🚀 Starting automatic message producer..."
echo "Press Ctrl+C to stop"
echo ""

COUNT=0
while true; do
    COUNT=$((COUNT + 1))
    TIMESTAMP=$(date '+%H:%M:%S')
    MESSAGE="[${TIMESTAMP}] Auto-message #${COUNT} from demo"
    
    echo "📤 Sending: ${MESSAGE}"
    echo "${MESSAGE}" | /opt/kafka/bin/kafka-console-producer.sh \
        --topic ${TOPIC} \
        --bootstrap-server ${BOOTSTRAP} \
        --property "parse.key=false" \
        --property "ignore.error=true" 2>/dev/null
    
    sleep 2
done
```

Сделайте его исполняемым:
```bash
chmod +x send_messages.sh
```

## 🎬 Запуск демонстрации

### Терминал 1: Erlang Consumer (уже запущен)

При успешном запуске вы увидите:
```erlang
Erlang/OTP 28 [erts-16.4] ... 

Starting kafka_demo application...
========================================
kafka_console_printer starting...
========================================
✓ Subscribed to partition 0
✓ Subscribed to partition 1
✓ Subscribed to partition 2
========================================
kafka_console_printer ready!
Waiting for messages...
========================================

kafka_stats_event handler added successfully
kafka_demo started with my_kafka_client
===> Booted kafka_demo
1>
```

### Терминал 2: Запуск автоматического producer'а

```bash
# Открыть новый терминал
./send_messages.sh
```

Вы увидите:
```
🚀 Starting automatic message producer...
Press Ctrl+C to stop

📤 Sending: [13:25:01] Auto-message #1 from demo
📤 Sending: [13:25:03] Auto-message #2 from demo
📤 Sending: [13:25:05] Auto-message #3 from demo
...
```

## 📊 Ожидаемый вывод в Терминале 1 (Consumer)

```
=== Kafka Message Set ===
Topic: <<"my-test-topic">>
Partition: 0
First offset: 11
Message count: 1

  --- Message ---
  Offset: 11
  Key: <<>>
  Value: [13:25:01] Auto-message #1 from demo

gen_server received: [0] offset=11 value=[13:25:01] Auto-message #1 from demo

=== Kafka Message Set ===
Topic: <<"my-test-topic">>
Partition: 0
First offset: 12
Message count: 1

  --- Message ---
  Offset: 12
  Key: <<>>
  Value: [13:25:03] Auto-message #2 from demo

gen_server received: [0] offset=12 value=[13:25:03] Auto-message #2 from demo
[STATS] Processed 100 messages

=== Kafka Message Set ===
Topic: <<"my-test-topic">>
Partition: 0
First offset: 13
Message count: 1

  --- Message ---
  Offset: 13
  Key: <<>>
  Value: [13:25:05] Auto-message #3 from demo

gen_server received: [0] offset=13 value=[13:25:05] Auto-message #3 from demo
```

## 🔧 Интерактивные команды в Erlang shell

### Мониторинг статистики в реальном времени

```erlang
%% В Терминале 1 (Erlang shell)

%% 1. Проверка количества полученных сообщений
kafka_gen_server:get_messages_count().
%% Ответ: {ok, 42}

%% 2. Полная статистика
kafka_gen_server:get_stats().
%% Ответ: {state,42,42,1746112345}

%% 3. Сброс статистики
kafka_gen_server:reset_stats().
%% Ответ: ok

%% 4. Проверка после сброса
kafka_gen_server:get_messages_count().
%% Ответ: {ok, 0}
```

### Проверка состояния системы

```erlang
%% Дерево супервизии
supervisor:which_children(kafka_demo_sup).
%% Ответ: [{kafka_console_printer,<0.314.0>,worker,[kafka_console_printer]},
%%         {kafka_gen_server,<0.311.0>,worker,[kafka_gen_server]},
%%         {kafka_event_manager,<0.310.0>,worker,[kafka_event_manager]}]

%% Зарегистрированные обработчики событий
gen_event:which_handlers(kafka_event_manager).
%% Ответ: [kafka_stats_event]

%% Глобальная регистрация (distributed Erlang)
global:whereis_name(kafka_demo_sup).
%% Ответ: <0.309.0>
```

### Ручная отправка тестовых сообщений

```erlang
%% Отправка через brod
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, 
                  <<"manual-key">>, <<"Manual test message">>).

%% Пакетная отправка (10 сообщений)
lists:foreach(fun(I) ->
    brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0,
                      <<>>, list_to_binary("Batch message " ++ integer_to_list(I)))
end, lists:seq(1, 10)).
```

## 🧪 Демонстрация отказоустойчивости (Supervisor)

```erlang
%% 1. Найти PID consumer процесса
Pid = whereis(kafka_console_printer).
io:format("Consumer PID: ~p~n", [Pid]).

%% 2. Принудительно убить процесс
exit(Pid, kill).

%% 3. Наблюдаем в логах перезапуск:
%% =PROGRESS REPORT====
%%    supervisor: {local,kafka_demo_sup}
%%    started: [{pid,<0.320.0>},
%%              {id,kafka_console_printer},
%%              ...]

%% 4. Проверяем новый PID
NewPid = whereis(kafka_console_printer).
io:format("New consumer PID: ~p~n", [NewPid]).

%% 5. Убеждаемся, что сообщения продолжают обрабатываться
kafka_gen_server:get_messages_count().
```

## 📈 Демонстрация производительности

### Нагрузочный тест (1000 сообщений)

```erlang
%% В Erlang shell
load_test(N) when N > 0 ->
    lists:foreach(fun(I) ->
        Message = list_to_binary("Load test message " ++ integer_to_list(I)),
        brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<>>, Message),
        if I rem 100 == 0 ->
            io:format("Sent ~p messages~n", [I]);
           true -> ok
        end
    end, lists:seq(1, N)),
    io:format("Load test completed: ~p messages sent~n", [N]).

%% Запуск теста
load_test(1000).

%% Проверка результата
kafka_gen_server:get_messages_count().
%% Должно быть 1000 + предыдущие сообщения
```

## 🎯 Ключевые моменты для демонстрации

### 1. **Application Behaviour**
```erlang
application:start(kafka_demo).
application:stop(kafka_demo).
application:which_applications().
```

### 2. **Supervisor Strategy (rest_for_one)**
```erlang
%% Стратегия перезапуска: если падает kafka_console_printer,
%% перезапускаются только процессы, запущенные после него
supervisor:which_children(kafka_demo_sup).
```

### 3. **gen_server State Management**
```erlang
%% Состояние сохраняется между сообщениями
kafka_gen_server:get_stats().
kafka_gen_server:reset_stats().
```

### 4. **gen_event Handler System**
```erlang
%% Динамическое добавление/удаление обработчиков
gen_event:which_handlers(kafka_event_manager).
gen_event:delete_handler(kafka_event_manager, kafka_stats_event, []).
gen_event:add_handler(kafka_event_manager, kafka_stats_event, []).
```

### 5. **Kafka Integration via brod**
```erlang
%% Проверка создания producer/consumer
brod:get_producer(my_kafka_client, <<"my-test-topic">>, 0).
brod:get_consumer(my_kafka_client, <<"my-test-topic">>, 0).
```

## 🛑 Остановка демонстрации

### Остановка автоматической отправки:
```bash
# В Терминале 2 (producer)
Ctrl+C
```

### Остановка Erlang приложения:
```erlang
%% В Терминале 1 (Erlang shell)
application:stop(kafka_demo).
q().
```

## 📝 Чек-лист демонстрации

- [x] **Запуск приложения** - успешный старт всех OTP компонентов
- [x] **Подписка на Kafka топик** - все 3 партиции
- [x] **Прием сообщений** - красивое форматирование вывода
- [x] **Автоматическая отправка** - непрерывный поток сообщений
- [x] **Статистика** - счетчик сообщений в gen_server
- [x] **События** - stats event handler (каждые 100 сообщений)
- [x] **Отказоустойчивость** - перезапуск процессов супервизором
- [x] **Distributed Erlang** - глобальная регистрация процессов

## 🚀 Production релиз

```bash
# Сборка релиза
rebar3 release

# Запуск в production режиме
_build/default/rel/kafka_demo_release/bin/kafka_demo_release console

# Или как daemon
_build/default/rel/kafka_demo_release/bin/kafka_demo_release start

# Подключение к работающему узлу
_build/default/rel/kafka_demo_release/bin/kafka_demo_release remote_console

# Остановка
_build/default/rel/kafka_demo_release/bin/kafka_demo_release stop
```

```bash
cat > config/vm.args << 'EOF'
-name kafka_demo@127.0.0.1
-setcookie kafka_demo_cookie
EOF
```