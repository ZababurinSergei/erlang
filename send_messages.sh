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