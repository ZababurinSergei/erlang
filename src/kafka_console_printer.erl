-module(kafka_console_printer).
-behaviour(brod_topic_subscriber).

-include_lib("brod/include/brod.hrl").

-export([init/2, handle_message/3]).
-export([start_link/0, start_link/1]).

-record(state, {topic :: binary(), test_mode :: boolean()}).

%% Вариант без аргументов (для супервизора)
start_link() ->
    %% Проверяем тестовый режим
    case application:get_env(kafka_demo, test_mode, false) of
        true ->
            io:format("Starting kafka_console_printer in TEST MODE (no Kafka)~n"),
            {ok, spawn(fun test_loop/0)};
        false ->
            %% Реальный режим: подключаемся к Kafka
            try
                ClientId = my_kafka_client,
                Topic = <<"my-test-topic">>,
                ConsumerGroup = <<"kafka-demo-group">>,
                ConsumerConfig = [{begin_offset, earliest}],

                brod:start_consumer(ClientId, Topic, ConsumerConfig),
                brod:subscribe(ClientId, Topic, ConsumerGroup, self(), all),
                io:format("Starting kafka_console_printer in REAL MODE (with Kafka)~n"),
                {ok, self()}
            catch
                _:Error ->
                    io:format("Warning: Kafka connection failed: ~p, switching to test mode~n", [Error]),
                    {ok, spawn(fun test_loop/0)}
            end
    end.

%% Заглушка для тестов
test_loop() ->
    receive
        stop -> ok;
        {brod, _Client, _Topic, _Partition, _Msg} ->
            timer:sleep(10),
            test_loop();
        _Other ->
            test_loop()
    after 1000 ->
        test_loop()
    end.

start_link(Config) ->
    ClientId = maps:get(client, Config, my_kafka_client),
    Topic = maps:get(topic, Config, <<"my-test-topic">>),
    ConsumerGroup = application:get_env(kafka_demo, consumer_group, <<"kafka-demo-group">>),
    ConsumerConfig = maps:get(consumer_config, Config, [{begin_offset, earliest}]),

    %% Запускаем consumer
    brod:start_consumer(ClientId, Topic, ConsumerConfig),

    %% Подписываемся
    ok = brod:subscribe(ClientId, Topic, ConsumerGroup, self(), all),

    {ok, self()}.

init(Topic, _InitArg) ->
    {ok, [], #state{topic = Topic, test_mode = false}}.

handle_message(Partition, Message, State) ->
    %% Message уже является записью kafka_message
    Offset = Message#kafka_message.offset,
    Key = Message#kafka_message.key,
    Value = Message#kafka_message.value,

    %% Отправляем событие в gen_event manager
    gen_event:notify(kafka_event_manager, {message_received, Partition, Offset}),

    %% Обновляем статистику через gen_server
    gen_server:cast(kafka_gen_server, {kafka_message, Partition, Offset, Value}),

    %% Печать в консоль
    io:format("~n--- Kafka Message ---~n"
              "Partition: ~p~n"
              "Offset: ~p~n"
              "Key: ~p~n"
              "Value: ~s~n"
              "---------------------~n",
              [Partition, Offset, Key, Value]),

    {ok, ack, State}.