# Kafka Demo on Erlang/OTP

## 📚 Содержание

1. [Описание проекта](#описание-проекта)
2. [Архитектура](#архитектура)
   - [Компоненты OTP](#компоненты-otp)
   - [Схема взаимодействия](#схема-взаимодействия)
   - [Поток данных](#поток-данных)
3. [Требования](#требования)
4. [Установка и сборка](#установка-и-сборка)
5. [Конфигурация](#конфигурация)
6. [Способы запуска](#способы-запуска)
   - [Режим 1: Интерактивная консоль (разработка)](#режим-1-интерактивная-консоль-разработка)
   - [Режим 2: Production релиз](#режим-2-production-релиз)
   - [Режим 3: Распределённый запуск](#режим-3-распределённый-запуск)
7. [Выполняемая работа](#выполняемая-работа)
   - [Что делает приложение](#что-делает-приложение)
   - [Демонстрируемые возможности OTP](#демонстрируемые-возможности-otp)
8. [Тестирование](#тестирование)
9. [Мониторинг и отладка](#мониторинг-и-отладка)
10. [Устранение неполадок](#устранение-неполадок)

---

## Описание проекта

Демонстрационное приложение на **Erlang/OTP**, которое подключается к Apache Kafka, читает сообщения из топика и обрабатывает их с использованием всех ключевых компонентов OTP.

---

## Архитектура

### Компоненты OTP

| Компонент | Реализация | Назначение |
|-----------|------------|------------|
| **Application behaviour** | `kafka_demo_app.erl` | Управление жизненным циклом приложения (start/stop/pre_stop) |
| **Supervisor behaviour** | `kafka_demo_sup.erl` | Дерево супервизии со стратегией `rest_for_one` |
| **gen_server** | `kafka_gen_server.erl` | Хранение состояния, синхронные/асинхронные вызовы |
| **gen_event** | `kafka_event_manager.erl` + `kafka_stats_event.erl` | Событийная модель и динамические обработчики |
| **Application Resource File** | `kafka_demo.app` | Метаданные приложения, зависимости, модули |
| **Release** | `relx.config` + `vm.args` | Сборка production-ready релиза |
| **Distributed Erlang** | `global:register_name/2` | Регистрация процессов в кластере |

### Схема взаимодействия

```
┌─────────────────────────────────────────────────────────────┐
│                    kafka_demo Application                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              kafka_demo_sup (supervisor)             │    │
│  │                 strategy: rest_for_one                │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                   │
│         ┌─────────────────┼─────────────────┐                │
│         ▼                 ▼                 ▼                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   gen_event │  │  gen_server │  │ kafka_console_      │  │
│  │   manager   │  │   stats     │  │ printer (subscriber)│  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         │                                                │    │
│         ▼                                                │    │
│  ┌─────────────┐                                         │    │
│  │   stats_    │◄────────────────────────────────────────┘    │
│  │   event     │      (sends events to gen_event)             │
│  └─────────────┘                                              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
│
▼
┌───────────┐
│   Kafka   │
│  Broker   │
└───────────┘
```

### Поток данных

1. **Kafka Broker** → `kafka_console_printer` (brod subscriber)
2. `kafka_console_printer` → `gen_event:notify()` → `kafka_stats_event`
3. `kafka_console_printer` → `gen_server:cast()` → `kafka_gen_server`
4. `kafka_gen_server` хранит статистику (счётчик сообщений, последний offset)

---

## Требования

- Erlang/OTP 24 или выше (рекомендуется 28)
- Apache Kafka (локально или удалённо)
- rebar3

---

## Установка и сборка

```bash
# Клонирование проекта
cd ~/kafka_demo

# Сборка зависимостей и компиляция
rebar3 compile

# Запуск тестов
rebar3 eunit

# Сборка production релиза
rebar3 release
```

---

## Конфигурация

### Основные параметры (`config/sys.config`)

```erlang
[
 {brod, [
    {auto_start_client, true},
    {default_client_id, my_kafka_client},
    {clients, [
        {my_kafka_client, [
            {endpoints, [{"localhost", 9092}]},
            {reconnect_cool_down_seconds, 10}
        ]}
    ]}
 ]},
 {kafka_demo, [
    {kafka_hosts, [{"localhost", 9092}]},
    {client_id, my_kafka_client},
    {topic, <<"my-test-topic">>},
    {consumer_group, <<"kafka-demo-group">>},
    {begin_offset, earliest},
    {test_mode, false}
 ]}
].
```

### Создание топика в Kafka

```bash
/opt/kafka/bin/kafka-topics.sh --create \
  --topic my-test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

---

## Способы запуска

### Режим 1: Интерактивная консоль (разработка)

```bash
rebar3 shell
```

В консоли Erlang:

```erlang
%% Запуск приложения
application:start(kafka_demo).

%% Проверка статистики
kafka_gen_server:get_stats().

%% Отправка тестового сообщения
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<>>, <<"test">>).

%% Остановка приложения
application:stop(kafka_demo).
```

### Режим 2: Production релиз

```bash
# Сборка релиза
rebar3 release

# Запуск в foreground
_build/default/rel/kafka_demo_release/bin/kafka_demo_release console

# Запуск как daemon
_build/default/rel/kafka_demo_release/bin/kafka_demo_release start

# Остановка
_build/default/rel/kafka_demo_release/bin/kafka_demo_release stop

# Подключение к запущенному узлу
_build/default/rel/kafka_demo_release/bin/kafka_demo_release remote_console
```

### Режим 3: Распределённый запуск

```bash
# Нода 1
erl -sname demo1 -setcookie demo_cookie -config config/sys.config
> application:start(kafka_demo).

# Нода 2
erl -sname demo2 -setcookie demo_cookie
> global:whereis_name(kafka_demo_sup).  % Должен вернуть pid из demo1
```

---

## Выполняемая работа

### Что делает приложение

1. **Подключается к Kafka** через клиентскую библиотеку `brod`
2. **Подписывается на топик** `my-test-topic` (все 3 партиции)
3. **Принимает сообщения** из Kafka в реальном времени
4. **Выводит сообщения** в консоль в отформатированном виде
5. **Ведёт статистику**:
    - Общее количество полученных сообщений
    - Последний полученный offset
    - Время запуска
6. **Генерирует события** каждые 100 сообщений
7. **Обеспечивает отказоустойчивость** через супервизор

### Демонстрируемые возможности OTP

| Возможность | Как демонстрируется |
|-------------|---------------------|
| **Application behaviour** | Управление стартом/стопом приложения, пред-остановка |
| **Supervisor (rest_for_one)** | При падении subscriber перезапускаются только зависимые процессы |
| **gen_server** | Хранение статистики, синхронные вызовы (`get_stats`) |
| **gen_event** | Динамическое добавление/удаление обработчиков событий |
| **Release сборка** | Production-ready релиз с `vm.args` и `sys.config` |
| **Distributed Erlang** | Глобальная регистрация процессов через `global` |
| **Logger** | Системное логирование OTP |

---

## Тестирование

```bash
# Запуск всех тестов
rebar3 eunit

# Запуск с детализацией
rebar3 eunit --verbose
```

### Отправка тестовых сообщений

**Через Kafka CLI:**
```bash
/opt/kafka/bin/kafka-console-producer.sh \
  --topic my-test-topic \
  --bootstrap-server localhost:9092
> Hello World
> Test message
```

**Через Erlang shell:**
```erlang
%% Одиночное сообщение
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<>>, <<"test">>).

%% Пакетная отправка (100 сообщений)
lists:foreach(fun(I) ->
    brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0,
                      <<>>, list_to_binary("Msg " ++ integer_to_list(I)))
end, lists:seq(1, 100)).
```

---

## Мониторинг и отладка

```erlang
%% Просмотр статистики
kafka_gen_server:get_stats().
kafka_gen_server:get_messages_count().
kafka_gen_server:reset_stats().

%% Дерево супервизии
supervisor:which_children(kafka_demo_sup).

%% Event manager handlers
gen_event:which_handlers(kafka_event_manager).

%% Зарегистрированные процессы
registered().

%% Глобальная регистрация
global:whereis_name(kafka_demo_sup).

%% Состояние gen_server
sys:get_status(kafka_gen_server).
```

---

## Устранение неполадок

### Kafka не запущена

**Ошибка:** `{error, {brod_client, start_link, ...}}`

**Решение:**
```bash
sudo systemctl status kafka
sudo systemctl start kafka
```

### Топик не существует

**Ошибка:** `{error, {topic_not_found, ...}}`

**Решение:**
```bash
/opt/kafka/bin/kafka-topics.sh --create \
  --topic my-test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

### Cookie mismatch при distributed режиме

**Ошибка:** `Connection attempt from node with wrong cookie`

**Решение:** Запускайте ноды с одинаковым cookie:
```bash
erl -sname node1 -setcookie same_cookie
erl -sname node2 -setcookie same_cookie
```

### Релиз не запускается из-за logger

**Решение:** Убедитесь, что в `config/sys.config` нет секции `logger` (или она корректна для вашей версии Erlang/OTP).

---

## Ожидаемый вывод при успешном запуске

```
Starting kafka_demo application...
kafka_stats_event handler added successfully
kafka_demo started with my_kafka_client

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

--- Kafka Message ---
Partition: 0
Offset: 42
Key: <<>>
Value: Hello from Kafka!
---------------------

[STATS] Processed 100 messages
```

---

## Лицензия

MIT