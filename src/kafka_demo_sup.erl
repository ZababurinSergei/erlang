-module(kafka_demo_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Демонстрация разных типов дочерних процессов
    Children = [
        %% gen_event manager
        #{id => kafka_event_manager,
          start => {kafka_event_manager, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [kafka_event_manager]},

        %% gen_server для статистики
        #{id => kafka_gen_server,
          start => {kafka_gen_server, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [kafka_gen_server]},

        %% Kafka subscriber
        #{id => kafka_console_printer,
          start => {kafka_console_printer, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [kafka_console_printer]}
    ],

    %% Стратегия: rest_for_one - если падает subscriber,
    %% перезапускаем его и всё, что после него
    {ok, {{rest_for_one, 10, 60}, Children}}.