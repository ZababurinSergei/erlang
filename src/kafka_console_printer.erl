-module(kafka_console_printer).
-behaviour(gen_server).

-export([start_link/0, start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("brod/include/brod.hrl").

-define(CLIENT, my_kafka_client).
-define(TOPIC, <<"my-test-topic">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start_link(_Config) ->
    start_link().

init([]) ->
    io:format("~n========================================~n"),
    io:format("kafka_console_printer starting...~n"),
    io:format("========================================~n"),

    %% Создаем producer с отключенной компрессией
    brod:start_producer(?CLIENT, ?TOPIC, [{compression, no_compression}]),

    %% Создаем consumer для всех партиций
    brod:start_consumer(?CLIENT, ?TOPIC, [{begin_offset, earliest}]),

    %% Ждем создания consumer'ов
    timer:sleep(1000),

    %% Подписываемся на партиции
    subscribe_partition(0),
    subscribe_partition(1),
    subscribe_partition(2),

    io:format("========================================~n"),
    io:format("kafka_console_printer ready!~n"),
    io:format("Waiting for messages...~n"),
    io:format("========================================~n~n"),

    {ok, #{}}.

subscribe_partition(Partition) ->
    case brod:get_consumer(?CLIENT, ?TOPIC, Partition) of
        {ok, ConsumerPid} ->
            brod:subscribe(ConsumerPid, self(), [{begin_offset, earliest}]),
            io:format("✓ Subscribed to partition ~p~n", [Partition]);
        _Error ->
            io:format("✗ Failed to get consumer for partition ~p~n", [Partition])
    end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Обработка сообщений от consumer-процесса
%% Формат: {ConsumerPid, {kafka_message_set, Topic, Partition, FirstOffset, Messages}}
handle_info({_ConsumerPid, {kafka_message_set, Topic, Partition, FirstOffset, Messages}}, State) ->
    io:format("~n=== Kafka Message Set ===~n"),
    io:format("Topic: ~p~n", [Topic]),
    io:format("Partition: ~p~n", [Partition]),
    io:format("First offset: ~p~n", [FirstOffset]),
    io:format("Message count: ~p~n", [length(Messages)]),

    lists:foreach(fun(#kafka_message{offset=O, key=K, value=V}) ->
        io:format("  ~n  --- Message ---~n"),
        io:format("  Offset: ~p~n", [O]),
        io:format("  Key: ~p~n", [K]),
        io:format("  Value: ~s~n", [V]),

        %% Отправляем в gen_server для статистики
        gen_server:cast(kafka_gen_server, {kafka_message, Partition, O, V})
                  end, Messages),

    gen_event:notify(kafka_event_manager, {messages_received, Partition, length(Messages)}),
    {noreply, State};

%% Альтернативный формат: {kafka_message_set, Topic, Partition, FirstOffset, Messages} (без PID)
handle_info({kafka_message_set, Topic, Partition, FirstOffset, Messages}, State) ->
    io:format("~n=== Kafka Message Set (no PID) ===~n"),
    io:format("Topic: ~p~n", [Topic]),
    io:format("Partition: ~p~n", [Partition]),
    io:format("First offset: ~p~n", [FirstOffset]),
    io:format("Message count: ~p~n", [length(Messages)]),

    lists:foreach(fun(#kafka_message{offset=O, key=K, value=V}) ->
        io:format("  ~n  --- Message ---~n"),
        io:format("  Offset: ~p~n", [O]),
        io:format("  Key: ~p~n", [K]),
        io:format("  Value: ~s~n", [V]),

        gen_server:cast(kafka_gen_server, {kafka_message, Partition, O, V})
                  end, Messages),

    gen_event:notify(kafka_event_manager, {messages_received, Partition, length(Messages)}),
    {noreply, State};

%% Обработка одиночных сообщений (старый формат с оберткой brod)
handle_info({brod, ?CLIENT, ?TOPIC, Partition, #kafka_message{offset=O, key=K, value=V}}, State) ->
    io:format("~n--- Kafka Message ---~n"),
    io:format("Partition: ~p~n", [Partition]),
    io:format("Offset: ~p~n", [O]),
    io:format("Key: ~p~n", [K]),
    io:format("Value: ~s~n", [V]),
    io:format("--------------------~n"),

    gen_server:cast(kafka_gen_server, {kafka_message, Partition, O, V}),
    gen_event:notify(kafka_event_manager, {message_received, Partition, O}),
    {noreply, State};

%% Отладочный вывод для непонятных сообщений
handle_info(Info, State) ->
    io:format("~n[DEBUG] Unexpected message: ~p~n", [Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    io:format("kafka_console_printer terminating~n"),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.