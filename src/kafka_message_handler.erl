-module(kafka_message_handler).
-behaviour(brod_topic_subscriber).

-export([init/2, handle_message/3]).

-include_lib("brod/include/brod.hrl").

init(Topic, _InitArg) ->
  io:format("Subscriber initialized for topic ~s~n", [Topic]),
  {ok, #{}}.

handle_message(Partition, #kafka_message{offset=Offset, key=Key, value=Value}, State) ->
  io:format("~n>>> MSG: p=~p, o=~p, k=~p, v=~s~n", [Partition, Offset, Key, Value]),

  %% Update statistics in gen_server
  gen_server:cast(kafka_gen_server, {kafka_message, Partition, Offset, Value}),

  %% Notify event manager
  gen_event:notify(kafka_event_manager, {message_received, Partition, Offset}),

  {ok, ack, State}.