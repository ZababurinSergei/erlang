-module(kafka_demo_app).
-behaviour(application).

-export([start/2, stop/1, pre_stop/1, config_change/3]).

start(_StartType, _StartArgs) ->
    %% Демонстрация порядка запуска
    io:format("Starting kafka_demo application...~n"),

    %% Запуск зависимостей
    {ok, _} = application:ensure_all_started(brod),

    %% Настройка логирования OTP
    ok = logger:set_primary_config(level, info),

    %% Конфигурация Kafka через application env
    KafkaHosts = application:get_env(kafka_demo, kafka_hosts, [{"localhost", 9092}]),
    ClientId = application:get_env(kafka_demo, client_id, my_kafka_client),
    _Topic = application:get_env(kafka_demo, topic, <<"my-test-topic">>),

    %% Старт клиента
    ok = brod:start_client(KafkaHosts, ClientId, []),

    %% Старт супервизора
    {ok, SupPid} = kafka_demo_sup:start_link(),

    %% Подключаем stats event handler
    case kafka_stats_event:add_handler() of
        ok ->
            io:format("kafka_stats_event handler added successfully~n");
        {error, Reason} ->
            io:format("Failed to add kafka_stats_event handler: ~p~n", [Reason])
    end,

    %% Регистрация для distributed discovery
    global:register_name(kafka_demo_sup, SupPid),

    io:format("kafka_demo started with ~p~n", [ClientId]),

    {ok, #{sup_pid => SupPid}}.

pre_stop(State) ->
    %% Graceful shutdown
    io:format("Preparing to stop kafka_demo...~n"),

    %% Удаляем обработчик перед остановкой
    gen_event:delete_handler(kafka_event_manager, kafka_stats_event, []),
    io:format("kafka_stats_event handler removed~n"),

    ok = brod:stop_client(my_kafka_client),
    State.

stop(_State) ->
    io:format("kafka_demo stopped~n"),
    ok.

config_change(Changed, _New, _Removed) ->
    %% Hot config reload
    io:format("Config changed: ~p~n", [Changed]),
    ok.