# Kafka Demo on Erlang/OTP

## Описание приложения

Демонстрационное приложение на **Erlang/OTP**, которое подключается к Apache Kafka, читает сообщения из топика и обрабатывает их с использованием всех ключевых компонентов OTP.

### Демонстрируемые компоненты OTP

| Компонент | Реализация | Назначение |
|-----------|------------|------------|
| **Application behaviour** | `kafka_demo_app.erl` | Управление жизненным циклом приложения (start/stop/pre_stop) |
| **Supervisor behaviour** | `kafka_demo_sup.erl` | Дерево супервизии со стратегией `rest_for_one` |
| **gen_server** | `kafka_gen_server.erl` | Хранение состояния, синхронные/асинхронные вызовы |
| **gen_event** | `kafka_event_manager.erl` + `kafka_stats_event.erl` | Событийная модель и динамические обработчики |
| **Application Resource File** | `kafka_demo.app` | Метаданные приложения, зависимости, модули |
| **Release** | `relx.config` + `vm.args` | Сборка production-ready релиза |
| **Distributed Erlang** | `global:register_name/2` | Регистрация процессов в кластере |
| **Logger** | `logger:set_primary_config/2` | OTP системное логирование |

### Архитектура

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

## Требования

- Erlang/OTP 24 или выше
- Apache Kafka (локально или удалённо)
- rebar3

## Установка и сборка

```bash
# Клонирование проекта
git clone <repo-url>
cd kafka_demo

# Сборка зависимостей и компиляция
rebar3 compile

# Запуск тестов
rebar3 eunit

# Сборка production релиза
rebar3 release
```

## Конфигурация

### Kafka подключение

По умолчанию приложение ожидает Kafka на `localhost:9092`.
Изменить параметры можно в `config/sys.config`:

```erlang
[
 {brod, [
    {clients, [
        {my_kafka_client, [
            {endpoints, [{"your-kafka-host", 9092}]}
        ]}
    ]}
 ]}
].
```

### Топик

По умолчанию используется топик `<<"my-test-topic">>`.
Создайте его в Kafka перед запуском:

```bash
kafka-topics --create --topic my-test-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

## Запуск

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

%% Отправка тестового сообщения (для отладки)
gen_server:cast(kafka_gen_server, {kafka_message, 0, 999, <<"test">>}).

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

# Просмотр статуса
_build/default/rel/kafka_demo_release/bin/kafka_demo_release status

# Подключение к запущенному узлу
_build/default/rel/kafka_demo_release/bin/kafka_demo_release remote_console
```

### Режим 3: Распределённый запуск (несколько нод)

```bash
# Нода 1
erl -sname demo1 -setcookie demo_cookie -config config/sys.config
> application:start(kafka_demo).

# Нода 2
erl -sname demo2 -setcookie demo_cookie -config config/sys.config
> global:whereis_name(kafka_demo_sup).  % Должен вернуть pid из demo1
```

## Тестирование

### Запуск всех тестов

```bash
rebar3 eunit
```

### Отправка тестовых сообщений в Kafka

Используя Kafka CLI:

```bash
# Producer
kafka-console-producer --topic my-test-topic --bootstrap-server localhost:9092
> Hello from Kafka
> Message 2
> {"json": "data"}
```

Используя `brod` из консоли Erlang:

```erlang
%% Отправка сообщения через brod
brod:produce_sync(my_kafka_client, <<"my-test-topic">>, 0, <<"key">>, <<"value">>).
```

### Мониторинг и отладка

```erlang
%% Просмотр состояния gen_server
sys:get_status(kafka_gen_server).

%% Просмотр дерева супервизии
supervisor:which_children(kafka_demo_sup).

%% Просмотр зарегистрированных процессов
registered().

%% Просмотр событий в event manager
gen_event:which_handlers(kafka_event_manager).

%% Получение статистики
kafka_gen_server:get_stats().
```

## Ожидаемый вывод

При успешном запуске и получении сообщения из Kafka:

```
--- Kafka Message ---
Topic: my-test-topic
Partition: 0
Offset: 42
Key: some_key
Value: Hello from Kafka
---------------------

[STATS] Processed 100 messages
```

## Требования к собеседованию (checklist)

- [x] Application behaviour (`kafka_demo_app.erl`)
- [x] Top-level supervisor (`kafka_demo_sup.erl`) со стратегией `rest_for_one`
- [x] Application resource file (`kafka_demo.app`)
- [x] Release configuration (`relx.config` + `vm.args`)
- [x] `gen_server` для хранения состояния (`kafka_gen_server.erl`)
- [x] `gen_event` для событийной модели (`kafka_event_manager.erl` + `kafka_stats_event.erl`)
- [x] Интеграция с Kafka через `brod`
- [x] Тесты (EUnit)
- [x] Документация (README.md)

## Устранение неполадок

### Kafka не запущена

**Ошибка:** `{error, {brod_client, start_link, ...}}`

**Решение:** Убедитесь, что Kafka запущена и доступна:

```bash
kafka-topics --list --bootstrap-server localhost:9092
```

### Топик не существует

**Ошибка:** `{error, {topic_not_found, ...}}`

**Решение:** Создайте топик:

```bash
kafka-topics --create --topic my-test-topic --bootstrap-server localhost:9092
```

### Cookie mismatch при distributed режиме

**Ошибка:** `Connection attempt from node with wrong cookie`

**Решение:** Запускайте ноды с одинаковым cookie:

```bash
erl -sname node1 -setcookie same_cookie
erl -sname node2 -setcookie same_cookie
```

## Лицензия

MIT