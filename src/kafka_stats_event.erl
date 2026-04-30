-module(kafka_stats_event).
-behaviour(gen_event).

-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2, code_change/3]).

% Public API
-export([add_handler/0, add_handler/1, remove_handler/0]).

add_handler() ->
    add_handler([]).

add_handler(Args) ->
    gen_event:add_handler(kafka_event_manager, ?MODULE, Args).

remove_handler() ->
    gen_event:delete_handler(kafka_event_manager, ?MODULE, []).

init([]) ->
    {ok, #{count => 0}}.

%% Обработка событий
handle_event({message_received, _Partition, _Offset}, State) ->
    NewCount = maps:get(count, State) + 1,
    if NewCount rem 100 == 0 ->
        io:format("[STATS] Processed ~p messages~n", [NewCount]);
       true -> ok
    end,
    {ok, State#{count := NewCount}};

handle_event(_Event, State) ->
    {ok, State}.

handle_call(_Request, State) ->
    {ok, State, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.