-module(kafka_gen_server).
-behaviour(gen_server).

%% API
-export([start_link/0, get_stats/0, reset_stats/0, get_state/0, get_messages_count/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
    messages_received = 0,
    last_offset = undefined,
    start_time = undefined
}).

%% ===================================================================
%% API
%% ===================================================================
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_stats() ->
    gen_server:call(?MODULE, get_stats).

reset_stats() ->
    gen_server:cast(?MODULE, reset_stats).

get_state() ->
    gen_server:call(?MODULE, get_state).

%% Новая функция для простого получения счётчика
get_messages_count() ->
    {ok, Count} = gen_server:call(?MODULE, get_messages_count),
    Count.

%% ===================================================================
%% gen_server callbacks
%% ===================================================================
init([]) ->
    process_flag(trap_exit, true),
    {ok, #state{start_time = erlang:system_time(seconds)}}.

handle_call(get_stats, _From, State) ->
    {reply, State, State};

handle_call(get_state, _From, State) ->
    {reply, State, State};

handle_call(get_messages_count, _From, #state{messages_received = Count} = State) ->
    {reply, {ok, Count}, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(reset_stats, _State) ->
    {noreply, #state{start_time = erlang:system_time(seconds)}};

handle_cast({kafka_message, Partition, Offset, Value}, State) ->
    NewState = State#state{
        messages_received = State#state.messages_received + 1,
        last_offset = Offset
    },
    io:format("gen_server received: [~p] offset=~p value=~s~n",
              [Partition, Offset, Value]),
    {noreply, NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    %% io:format("gen_server terminating, flushing stats...~n"),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.