# Что такое OTP?

**OTP** (Open Telecom Platform) — это набор библиотек, фреймворков и принципов проектирования, поставляемый вместе с языком программирования **Erlang**. Несмотря на название "телекоммуникационная платформа", сегодня OTP — это универсальный инструмент для построения **отказоустойчивых, масштабируемых и конкурентных систем**.

## 🎯 Основная концепция

OTP — это не просто библиотека, а **архитектурная философия** для построения промышленных систем, которые должны работать 24/7 без остановки.

## 📦 Ключевые компоненты OTP

### 1. **Behaviours (Поведения)**
Шаблоны проектирования для стандартных компонентов:

| Behaviour | Назначение | Когда использовать |
|-----------|------------|-------------------|
| `gen_server` | Универсальный сервер | Хранение состояния, обработка запросов |
| `gen_event` | Событийный менеджер | Логирование, метрики, уведомления |
| `gen_statem` | Конечный автомат | Протоколы, машины состояний |
| `gen_fsm` (устаревший) | Конечный автомат | Заменён на `gen_statem` |
| `supervisor` | Наблюдатель | Управление жизненным циклом процессов |

### 2. **Supervision Tree (Дерево супервизии)**
Иерархическая структура процессов, где родители следят за детьми и перезапускают их при падении.

```
                 ┌─────────────┐
                 │  Supervisor │
                 └──────┬──────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ Worker  │    │ Worker  │    │Supervisor│
    └─────────┘    └─────────┘    └────┬────┘
                                        │
                                    ┌───┴───┐
                                    ▼      ▼
                                ┌─────┐ ┌─────┐
                                │Worker│ │Worker│
                                └─────┘ └─────┘
```

**Стратегии перезапуска:**
- `one_for_one` — перезапуск только упавшего процесса
- `one_for_all` — перезапуск всех дочерних процессов
- `rest_for_one` — перезапуск упавшего и всех, кто запущен после него

### 3. **Application (Приложение)**
Инкапсулирует целое приложение как единицу развёртывания:
- `application:start/1` — запуск всего приложения
- `application:stop/1` — остановка
- `application:get_env/2` — конфигурация

### 4. **Release (Релиз)**
Самостоятельный пакет для deployment:
- Включает ERTS (Erlang Runtime System)
- Содержит все зависимости
- Может запускаться как systemd сервис

## 🔥 Ключевые принципы OTP

### 1. **Let it crash**
Не пишите защитный код для каждого случая. Если процесс упал — супервизор его перезапустит.

```erlang
%% ❌ Плохо (over-defensive)
case file:read_file("config.txt") of
    {ok, Content} -> process(Content);
    {error, _} -> handle_error()
end.

%% ✅ Хорошо (let it crash)
Content = file:read_file("config.txt"),  % Упадёт, супервизор перезапустит
process(Content).
```

### 2. **Fail fast**
Обнаружили ошибку — немедленно упадите.

### 3. **Process isolation**
Каждый процесс изолирован: крах одного не влияет на другие.

## 🏗️ Пример архитектуры реального приложения

```erlang
%% Дерево супервизии для чат-сервера
sup:init([]) ->
    Children = [
        #{id => db_connection,   % БД
          start => {db, start_link, []}},
        #{id => user_manager,    % Управление пользователями
          start => {users, start_link, []}},
        #{id => room_sup,        % Супервизор комнат
          start => {room_sup, start_link, []},
          type => supervisor}
    ],
    {ok, {{rest_for_one, 5, 10}, Children}}.
```

## 📊 Сравнение с другими технологиями

| Концепция OTP | Аналог в других языках |
|---------------|------------------------|
| `gen_server` | Akka Actor (Scala), Erlang processes + OTP |
| `supervisor` | Kubernetes (но на уровне процессов) |
| `application` | Docker container + entrypoint |
| `release` | Docker image + runtime |
| `let it crash` | Crash-only software |

## 🎓 Что нужно знать об OTP для собеседования

### Junior
- OTP — это фреймворк для отказоустойчивых систем
- Основные behaviours: `gen_server`, `supervisor`, `application`
- Дерево супервизии перезапускает упавшие процессы

### Middle
- Стратегии перезапуска супервизора (`one_for_one`, `rest_for_one`, `one_for_all`)
- Разница между `gen_server:call` (синхронный) и `gen_server:cast` (асинхронный)
- Как работает `sys.config` и `vm.args`

### Senior
- Hot code upgrade (обновление кода без остановки)
- Release handling (разбор релизов, сценарии обновления)
- Распределённые приложения с `global` и `pg`
- Настройка `logger` и `sasl` для production

## 💡 Простой пример gen_server

```erlang
-module(counter).
-behaviour(gen_server).

%% API
-export([start/0, inc/0, get/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2]).

start() -> gen_server:start({local, ?MODULE}, ?MODULE, 0, []).
inc()  -> gen_server:cast(?MODULE, inc).
get()  -> gen_server:call(?MODULE, get).

init(InitialCount) -> {ok, InitialCount}.
handle_call(get, _From, Count) -> {reply, Count, Count}.
handle_cast(inc, Count) -> {noreply, Count + 1}.
```

**Использование:**
```erlang
counter:start(),
counter:inc(),
counter:inc(),
counter:get().  % 2
```

## 🔗 В вашем проекте kafka_demo

Вы используете:
- ✅ `gen_server` — `kafka_gen_server` (статистика)
- ✅ `gen_event` — `kafka_event_manager` + `kafka_stats_event`
- ✅ `supervisor` — `kafka_demo_sup` (стратегия `rest_for_one`)
- ✅ `application` — `kafka_demo_app` (жизненный цикл)
- ✅ `release` — relx.config (production сборка)

Это **полный стек OTP**! 🎯

## 📚 Итог

**OTP** — это не просто библиотека, а:
1. **Фреймворк** для построения надёжных систем
2. **Набор поведений** (gen_server, supervisor, etc.)
3. **Архитектурный паттерн** (деревья супервизии)
4. **Инструменты** для сборки релизов
5. **Философия** "let it crash" + "fail fast"

Вместе с Erlang'ом OTP позволяет создавать системы с **отказоустойчивостью 99.999%** (пять девяток), которые обновляются без остановки и работают годами.