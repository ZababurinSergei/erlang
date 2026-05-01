```bash
rp(brod:module_info(exports)).

io:format("~p~n", [brod:module_info(exports)]).

%% Построчный вывод
lists:foreach(fun({F, A}) -> io:format("~s/~p~n", [F, A]) end, brod:module_info(exports)).
```

```bash
%% Сохранить экспорты в файл
{ok, Fd} = file:open("brod_exports.txt", [write]),
lists:foreach(fun({F, A}) -> 
    io:format(Fd, "~s/~p~n", [F, A]) 
end, brod:module_info(exports)),
file:close(Fd),
io:format("Exports saved to brod_exports.txt~n").
```