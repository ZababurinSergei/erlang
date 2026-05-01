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

handle_info({brod, ?CLIENT, ?TOPIC, Partition, #kafka_message{offset=O, key=K, value=V}}, State) ->
    io:format("~n>>> MSG: p=~p, o=~p, k=~p, v=~s~n", [Partition, O, K, V]),
    gen_server:cast(kafka_gen_server, {kafka_message, Partition, O, V}),
    gen_event:notify(kafka_event_manager, {message_received, Partition, O}),
    {noreply, State};

handle_info(Info, State) ->
    io:format("~n[DEBUG] ~p~n", [Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.