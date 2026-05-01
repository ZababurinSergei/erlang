#!/usr/bin/env escript
%% -*- erlang -*-
-mode(compile).

main(["send", Message]) ->
    %% Отправляем сообщение через RPC
    Node = 'nonode@nohost',
    Cookie = 'nocookie',

    erlang:set_cookie(node(), Cookie),

    %% Пробуем подключиться
    case net_adm:ping(Node) of
        pong ->
            io:format("Connected to node~n"),
            %% Выполняем отправку
            Res = rpc:call(Node, brod, produce_sync,
                          [my_kafka_client, <<"my-test-topic">>, 0, <<>>,
                           list_to_binary(Message)]),
            case Res of
                ok -> io:format("✓ Message sent: ~s~n", [Message]);
                Error -> io:format("✗ Error: ~p~n", [Error])
            end;
        pang ->
            io:format("✗ Cannot connect to Erlang node~n"),
            io:format("Make sure rebar3 shell is running~n")
    end;

main(["stats"]) ->
    Node = 'nonode@nohost',
    Cookie = 'nocookie',

    erlang:set_cookie(node(), Cookie),

    case net_adm:ping(Node) of
        pong ->
            case rpc:call(Node, kafka_gen_server, get_messages_count, []) of
                {ok, Count} ->
                    io:format("✓ Messages processed: ~p~n", [Count]);
                Error ->
                    io:format("✗ Error: ~p~n", [Error])
            end;
        pang ->
            io:format("✗ Cannot connect~n")
    end;

main(["reset"]) ->
    Node = 'nonode@nohost',
    Cookie = 'nocookie',

    erlang:set_cookie(node(), Cookie),

    case net_adm:ping(Node) of
        pong ->
            rpc:call(Node, kafka_gen_server, reset_stats, []),
            io:format("✓ Statistics reset~n");
        pang ->
            io:format("✗ Cannot connect~n")
    end;

main(["batch", N, Partition]) ->
    Node = 'nonode@nohost',
    Cookie = 'nocookie',
    Count = list_to_integer(N),
    Part = list_to_integer(Partition),

    erlang:set_cookie(node(), Cookie),

    case net_adm:ping(Node) of
        pong ->
            io:format("Sending ~p messages...~n", [Count]),
            lists:foreach(fun(I) ->
                Msg = list_to_binary(io_lib:format("Batch msg ~p", [I])),
                rpc:call(Node, brod, produce_sync,
                        [my_kafka_client, <<"my-test-topic">>, Part, <<>>, Msg]),
                timer:sleep(100)
            end, lists:seq(1, Count)),
            io:format("✓ Sent ~p messages~n", [Count]);
        pang ->
            io:format("✗ Cannot connect~n")
    end;

main(["help"]) ->
    usage();

main(_) ->
    usage().

usage() ->
    io:format("Usage:~n"),
    io:format("  ./simple_control.escript send <message>~n"),
    io:format("  ./simple_control.escript stats~n"),
    io:format("  ./simple_control.escript reset~n"),
    io:format("  ./simple_control.escript batch <count> <partition>~n"),
    io:format("~nExamples:~n"),
    io:format("  ./simple_control.escript send \"Hello\"~n"),
    io:format("  ./simple_control.escript stats~n").