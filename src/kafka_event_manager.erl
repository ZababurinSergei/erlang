-module(kafka_event_manager).
-behaviour(gen_event).

-export([start_link/0]).
-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_event:start_link({local, ?MODULE}).

init([]) ->
    {ok, []}.

handle_event(_Event, State) ->
    %% Рассылаем всем обработчикам
    {ok, State}.

handle_call(_Request, State) ->
    {ok, State, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.