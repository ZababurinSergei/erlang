-module(kafka_demo_tests).
-include_lib("eunit/include/eunit.hrl").

-record(state, {
    messages_received = 0,
    last_offset = undefined,
    start_time = undefined
}).

%% ===================================================================
%% Тесты, которые НЕ требуют запуска глобальных процессов
%% ===================================================================

%% Тест 1: Прямое тестирование логики gen_server
direct_gen_server_test() ->
    State0 = #state{start_time = erlang:system_time(seconds)},
    ?assertEqual(0, State0#state.messages_received),
    ?assertEqual(undefined, State0#state.last_offset),

    State1 = State0#state{
        messages_received = State0#state.messages_received + 1,
        last_offset = 123
    },
    ?assertEqual(1, State1#state.messages_received),
    ?assertEqual(123, State1#state.last_offset),

    State2 = #state{start_time = erlang:system_time(seconds)},
    ?assertEqual(0, State2#state.messages_received),
    ok.

%% Тест 2: Тестирование API функций gen_server через изолированный процесс
isolated_gen_server_test() ->
    UniqueId = erlang:system_time(millisecond),
    ServerName = list_to_atom("iso_gen_server_" ++ integer_to_list(UniqueId)),

    {ok, _Pid} = gen_server:start_link({local, ServerName}, kafka_gen_server, [], []),

    {ok, 0} = gen_server:call(ServerName, get_messages_count),

    gen_server:cast(ServerName, {kafka_message, 0, 1, <<"test1">>}),
    timer:sleep(50),
    {ok, 1} = gen_server:call(ServerName, get_messages_count),

    gen_server:cast(ServerName, {kafka_message, 0, 2, <<"test2">>}),
    gen_server:cast(ServerName, {kafka_message, 0, 3, <<"test3">>}),
    timer:sleep(50),
    {ok, 3} = gen_server:call(ServerName, get_messages_count),

    gen_server:cast(ServerName, reset_stats),
    timer:sleep(50),
    {ok, 0} = gen_server:call(ServerName, get_messages_count),

    State = gen_server:call(ServerName, get_state),
    ?assertEqual(0, State#state.messages_received),

    gen_server:stop(ServerName),
    ok.

%% Тест 3: Тестирование event manager изолированно (ИСПРАВЛЕН)
isolated_event_test() ->
    UniqueId = erlang:system_time(millisecond),
    EvMgrName = list_to_atom("iso_ev_mgr_" ++ integer_to_list(UniqueId)),

    %% Создаем event manager
    {ok, EvMgr} = gen_event:start_link({local, EvMgrName}),

    %% Добавляем stats обработчик - add_handler возвращает ok, а не {ok, Pid}
    ok = gen_event:add_handler(EvMgrName, kafka_stats_event, []),

    %% Отправляем события
    ok = gen_event:notify(EvMgrName, {message_received, 0, 100}),
    ok = gen_event:notify(EvMgrName, {message_received, 0, 200}),
    timer:sleep(50),

    %% Удаляем обработчик
    ok = gen_event:delete_handler(EvMgrName, kafka_stats_event, []),
    timer:sleep(50),

    %% Останавливаем
    ok = gen_event:stop(EvMgr),
    timer:sleep(50),
    ok.

%% Тест 4: Тестирование модуля статистики отдельно
stats_event_module_test() ->
    %% Тестируем init
    {ok, State0} = kafka_stats_event:init([]),
    ?assert(is_map(State0)),
    ?assertEqual(0, maps:get(count, State0, 0)),

    %% Тестируем handle_event
    {ok, State1} = kafka_stats_event:handle_event({message_received, 0, 1}, State0),
    ?assertEqual(1, maps:get(count, State1)),

    {ok, State2} = kafka_stats_event:handle_event({message_received, 0, 2}, State1),
    ?assertEqual(2, maps:get(count, State2)),

    %% Тестируем обработку других событий
    {ok, State3} = kafka_stats_event:handle_event(some_other_event, State2),
    ?assertEqual(2, maps:get(count, State3)),

    %% Тестируем handle_call
    {ok, Reply, State4} = kafka_stats_event:handle_call(get_count, State3),
    ?assert(is_map(Reply)),
    ?assertEqual(2, maps:get(count, Reply, 0)),
    ?assertEqual(State3, State4),

    ok.

%% Тест 5: Тестирование console printer в тестовом режиме
console_printer_test() ->
    application:set_env(kafka_demo, test_mode, true),

    {ok, Pid} = kafka_console_printer:start_link(),
    timer:sleep(100),

    ?assert(is_process_alive(Pid)),

    exit(Pid, shutdown),
    timer:sleep(50),

    application:set_env(kafka_demo, test_mode, false),
    ok.

%% Тест 6: Тестирование kafka_gen_server без зависимостей
gen_server_module_test() ->
    {ok, InitState} = kafka_gen_server:init([]),
    ?assertEqual(0, InitState#state.messages_received),

    {reply, {ok, 0}, NewState1} = kafka_gen_server:handle_call(get_messages_count, {self(), make_ref()}, InitState),
    ?assertEqual(0, NewState1#state.messages_received),

    {reply, State, NewState2} = kafka_gen_server:handle_call(get_state, {self(), make_ref()}, InitState),
    ?assertEqual(InitState, State),
    ?assertEqual(0, NewState2#state.messages_received),

    {noreply, NewState3} = kafka_gen_server:handle_cast({kafka_message, 0, 42, <<"test">>}, InitState),
    ?assertEqual(1, NewState3#state.messages_received),
    ?assertEqual(42, NewState3#state.last_offset),

    {noreply, ResetState} = kafka_gen_server:handle_cast(reset_stats, NewState3),
    ?assertEqual(0, ResetState#state.messages_received),

    ok.

%% Тест 7: Прямое тестирование record операций
record_operations_test() ->
    S1 = #state{},
    ?assertEqual(0, S1#state.messages_received),
    ?assertEqual(undefined, S1#state.last_offset),

    S2 = S1#state{messages_received = 5, last_offset = 999},
    ?assertEqual(5, S2#state.messages_received),
    ?assertEqual(999, S2#state.last_offset),

    #state{messages_received = Count, last_offset = Offset} = S2,
    ?assertEqual(5, Count),
    ?assertEqual(999, Offset),

    ok.

%% Тест 8: Тестирование множественных вызовов
multiple_calls_test() ->
    UniqueId = erlang:system_time(millisecond),
    ServerName = list_to_atom("multi_gen_server_" ++ integer_to_list(UniqueId)),

    {ok, _Pid} = gen_server:start_link({local, ServerName}, kafka_gen_server, [], []),

    lists:foreach(fun(I) ->
        gen_server:cast(ServerName, {kafka_message, 0, I, <<"test">>})
    end, lists:seq(1, 100)),

    timer:sleep(200),

    {ok, 100} = gen_server:call(ServerName, get_messages_count),

    gen_server:stop(ServerName),
    ok.

%% Тест 9: Тестирование terminate callback
terminate_callback_test() ->
    %% Проверяем, что terminate не падает
    State = #state{messages_received = 10, last_offset = 999, start_time = erlang:system_time(seconds)},
    ok = kafka_gen_server:terminate(normal, State),
    ok.

%% ===================================================================
%% Запуск всех тестов
%% ===================================================================

all_test_() ->
    [
        {"Direct gen_server logic", fun direct_gen_server_test/0},
        {"Isolated gen_server process", fun isolated_gen_server_test/0},
        {"Isolated event manager", fun isolated_event_test/0},
        {"Stats event module", fun stats_event_module_test/0},
        {"Console printer in test mode", fun console_printer_test/0},
        {"Gen server module callbacks", fun gen_server_module_test/0},
        {"Record operations", fun record_operations_test/0},
        {"Multiple calls", fun multiple_calls_test/0},
        {"Terminate callback", fun terminate_callback_test/0}
    ].