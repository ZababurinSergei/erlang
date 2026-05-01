```bash
# Поиск пакета kafka_protocol
rebar3 pkgs kafka_protocol

# Поиск пакета brod
rebar3 pkgs brod
```

```bash
# Посмотреть последнюю версию pc
rebar3 hex info pc

# Поиск пакетов
rebar3 hex search pc

# Или показать все доступные версии
rebar3 hex info pc --all
```

```bash
curl https://hex.pm/api/packages/kafka_protocol  | grep -o '"version":"[^"]*"' | head -5
```

```bash
# Получить список версий kafka_protocol
curl -s https://hex.pm/api/packages/kafka_protocol | jq '.releases[].version'

# Получить список версий brod
curl -s https://hex.pm/api/packages/brod | jq '.releases[].version'
```

```bash
# Обновить индекс пакетов
rebar3 update

# Показать дерево зависимостей с версиями
rebar3 tree
```

Проверить совместимость:
```bash
rebar3 compile --deps_only
```

## Список полезных команд rebar3 для работы с зависимостями :

| Команда | Описание |
|---------|----------|
| `rebar3 update` | Обновить индекс пакетов Hex |
| `rebar3 pkgs <name>` | Поиск пакетов по имени |
| `rebar3 tree` | Показать дерево зависимостей |
| `rebar3 deps` | Список всех зависимостей |
| `rebar3 upgrade <dep>` | Обновить конкретную зависимость до последней версии |