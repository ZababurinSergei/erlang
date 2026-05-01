# Как установить Kafka на Ubuntu

На сегодняшний день существует два основных подхода к установке Apache Kafka на Ubuntu: **классическая установка из бинарных файлов** и **установка с помощью Docker**. Выбор зависит от ваших задач — для разработки и тестирования удобнее Docker, для production-среды подойдёт ручная установка.

В современных версиях Kafka (начиная с 4.0) больше не требуется отдельный ZooKeeper — используется встроенный механизм координации **KRaft** .

---

## Способ 1: Установка из бинарных файлов (рекомендуется для серверов)

Этот способ подходит для production-сред и даёт полный контроль над конфигурацией.

### Шаг 1: Установка Java

Kafka требует Java версии 17 или новее. Рекомендуется устанавливать OpenJDK 21 LTS :

```bash
sudo apt update
sudo apt install -y openjdk-21-jdk-headless
```

Проверьте установку:

```bash
java -version
```

### Шаг 2: Создание пользователя для Kafka

Для безопасности рекомендуется запускать Kafka от отдельного непривилегированного пользователя :

```bash
sudo useradd -r -m -s /usr/sbin/nologin kafka
```

### Шаг 3: Скачивание и распаковка Kafka

Скачайте актуальную версию Kafka с официального зеркала Apache:

```bash
KAFKA_VERSION="4.2.0"
SCALA_VERSION="2.13"
wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -O /tmp/kafka.tgz
```

Распакуйте архивы в директорию `/opt/kafka`:

```bash
sudo tar -xzf /tmp/kafka.tgz -C /opt
sudo mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka
sudo chown -R kafka:kafka /opt/kafka
rm -f /tmp/kafka.tgz
```

### Шаг 4: Настройка Kafka в режиме KRaft

Создайте директорию для хранения данных Kafka:

```bash
sudo mkdir -p /var/kafka-logs
sudo chown kafka:kafka /var/kafka-logs
```

Отредактируйте конфигурационный файл `server.properties`:

```bash
sudo vi /opt/kafka/config/server.properties
```

Замените содержимое файла следующей конфигурацией (замените `YOUR_SERVER_IP` на реальный IP-адрес вашего сервера или оставьте `localhost` для локальной разработки) :

```properties
# Режим KRaft: объединённый контроллер и брокер
node.id=1
process.roles=broker,controller

# Настройка кворума для одного узла
controller.quorum.voters=1@localhost:9093

# Настройка слушателей
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
advertised.listeners=PLAINTEXT://YOUR_SERVER_IP:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

# Директория для логов
log.dirs=/var/kafka-logs

# Параметры автоматического создания топиков
num.partitions=3
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

# Политика хранения (7 дней)
log.retention.hours=168
log.retention.bytes=1073741824
log.segment.bytes=1073741824
```

### Шаг 5: Генерация ID кластера и форматирование хранилища

Сгенерируйте уникальный ID для вашего Kafka-кластера :

```bash
KAFKA_CLUSTER_ID=$(sudo -u kafka /opt/kafka/bin/kafka-storage.sh random-uuid)
echo $KAFKA_CLUSTER_ID
```

Отформатируйте директорию для хранения с этим ID:

```bash
sudo -u kafka /opt/kafka/bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c /opt/kafka/config/server.properties
```

### Шаг 6: Создание systemd-сервиса

Создайте файл сервиса для автоматического запуска Kafka :

```bash
sudo vi /etc/systemd/system/kafka.service
```

Добавьте следующее содержимое:

```ini
[Unit]
Description=Apache Kafka Server (KRaft Mode)
Documentation=https://kafka.apache.org/documentation/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kafka
Group=kafka
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64"
Environment="KAFKA_HEAP_OPTS=-Xmx1G -Xms1G"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Запустите и включите сервис:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kafka
sudo systemctl status kafka
```

### Шаг 7: Настройка фаервола (при необходимости)

Если на сервере включен UFW, откройте порты для Kafka :

```bash
sudo ufw allow 9092/tcp comment "Kafka broker"
sudo ufw allow 9093/tcp comment "Kafka controller"
sudo ufw reload
```

---

## Способ 2: Установка с помощью Docker (рекомендуется для разработки)

Docker-способ значительно проще и быстрее — идеально подходит для локального тестирования и разработки .

### Шаг 1: Установка Docker и Docker Compose

Если Docker ещё не установлен:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### Шаг 2: Создание файла docker-compose.yml

Создайте директорию для проекта и файл `docker-compose.yml`:

```bash
mkdir -p ~/kafka-docker && cd ~/kafka-docker
vi docker-compose.yml
```

Добавьте следующую конфигурацию (актуально для Kafka 4.2.0) :

```yaml
services:
  kafka:
    image: apache/kafka:4.2.0
    container_name: kafka
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
    volumes:
      - kafka-data:/var/lib/kafka/data
    healthcheck:
      test: ["CMD-SHELL", "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  kafka-data:
```

### Шаг 3: Запуск Kafka

```bash
docker compose up -d
```

Проверьте статус контейнера:

```bash
docker compose ps
```

---

## Проверка работоспособности

### Создание топика

**Для ручной установки:**
```bash
/opt/kafka/bin/kafka-topics.sh --create --topic test-topic --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092
```

**Для Docker:**
```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create --topic test-topic --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092
```

### Отправка и получение сообщений

**Отправка сообщений (producer):**
```bash
echo -e "message-1\nmessage-2\nmessage-3" | docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server localhost:9092
```

**Получение сообщений (consumer):**
```bash
docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --from-beginning --max-messages 3 --bootstrap-server localhost:9092
```

Если вы видите отправленные сообщения — Kafka работает корректно .

---

## Сравнение способов установки

| Характеристика | Ручная установка | Docker |
|----------------|------------------|---------|
| **Сложность** | Высокая | Низкая |
| **Время установки** | 10-15 минут | 2-3 минуты |
| **Производственное окружение** | ✅ Рекомендуется | Требует оркестрации |
| **Разработка и тестирование** | Возможно | ✅ Рекомендуется |
| **Контроль над конфигурацией** | Полный | Базовый |
| **Обновление версий** | Вручную | Смена тега образа |

---

## Важное примечание о ZooKeeper

В старых версиях Kafka (до 4.0) требовался отдельный ZooKeeper для координации кластера. Начиная с Kafka 4.0, ZooKeeper полностью удалён из проекта — теперь используется встроенный механизм KRaft (Kafka Raft) . Если вы встретили в интернете руководства с настройкой ZooKeeper, они относятся к устаревшим версиям. В этом руководстве используется современный подход с KRaft.