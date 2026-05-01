```bash
pkill -f beam.smp
rm -f ~/.cache/rebar3/*_plt
rm -rf ~/.cache/rebar3
pkill -f beam.smp
rebar3 clean -a
# Удаляем ВСЁ
rm -rf _build
rm -rf deps
rm -rf rebar.lock
rm -rf _build
# Очищаем кэш rebar3
rm -rf ~/.cache/rebar3
```

```bash
pkill -f beam.smp
rm -f ~/.cache/rebar3/*_plt
rm -rf ~/.cache/rebar3
pkill -f beam.smp
rebar3 clean -a
# Удаляем ВСЁ
rm -rf _build
rm -rf deps
rm -rf rebar.lock
rm -rf _build
# Очищаем кэш rebar3
rm -rf ~/.cache/rebar3

rebar3 compile

rebar3 release

rebar3 shell
```

```bash
# Теперь собираем
rebar3 compile
```

```bash
# Теперь собираем
rebar3 release
```

```bash
# 3. Запуск тестов
rebar3 eunit --verbose
```

```bash
# Теперь собираем
rebar3 shell
```

```bash
rebar3 dialyzer
```

```bash
rebar3 xref
```


```bash
cat > ~/kafka_demo/src/kafka_console_printer.erl << 'EOF'
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

    %% Создаем producer
    brod:start_producer(?CLIENT, ?TOPIC, []),

    %% Используем start_consumer с 3 аргументами (как в экспортах)
    lists:foreach(fun(Partition) ->
        case brod:start_consumer(?CLIENT, ?TOPIC, Partition) of
            {ok, _ConsumerPid} ->
                %% Подписываемся на сообщения
                brod:subscribe(?CLIENT, ?TOPIC, Partition, self(), []),
                io:format("✓ Consumer started for partition ~p~n", [Partition]);
            {error, Reason} ->
                io:format("✗ Failed to start consumer for partition ~p: ~p~n", [Partition, Reason])
        end
    end, [0, 1, 2]),

    io:format("========================================~n"),
    io:format("kafka_console_printer ready!~n"),
    io:format("Waiting for messages...~n"),
    io:format("========================================~n~n"),

    {ok, #{}}.

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
EOF
```