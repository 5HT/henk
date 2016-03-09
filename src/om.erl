-module(om).
-description('CoC Compiler').
-behaviour(supervisor).
-behaviour(application).
-export([init/1, start/2, stop/1]).
-compile(export_all).

% providing functions

print(X)    -> io:format("~ts~n",[bin(X)]).
bin(X)      -> unicode:characters_to_binary(om:flat(om_parse:print(X,0))).
extract()   -> om_extract:scan().
type(S)     -> om_type:type(S).
erase(X)    -> om_erase:erase(X).
type(S,B)   -> om_type:type(S,B).
modes()     -> ["erased","girard","hurkens","normal","setoids"].
priv(Mode)  -> lists:concat([privdir(),"/",Mode]).
privdir()   -> application:get_env(om,priv,"priv").
mode(S)     -> application:set_env(om,mode,S).
mode()      -> application:get_env(om,mode,"erased").
debug(S)    -> application:set_env(om,debug,S).
debug()     -> application:get_env(om,debug,false).
name(M,P,F) -> string:join([priv(mode()),case P of [] -> F; _ -> P ++ "/" ++ F end],"/").
str(P,F)    -> om_tok:tokens(P,unicode:characters_to_binary(F),0,{1,[]},[]).
read(P,F)   -> om_tok:tokens(P,file(F),0,{1,[]},[]).
cname(F)    -> hd(lists:reverse(string:tokens(F,"/"))).
tname(F)    -> X= hd(tl(lists:reverse(string:tokens(F,"/")))), case X == om:mode() of true -> []; _ -> X end.
show(F)     -> Term = parse(tname(F),cname(F)),
               io:format("T: ~tp~n",[Term]),
               mad:info("~p~n~tsSize: ~p~n", [F,file(F),size(term_to_binary(Term))]),
               try om:type(Term), Term catch E:R -> io:format("~tp~n",[erlang:get_stacktrace()]), {error,{"om:show1",R}} end.
a(F)        -> case parse(F) of {error,R} -> {error,R}; {[],[A]} -> A end.
parse(X)    -> om_parse:expr([],om:str([],X),[]).
parse(P,F)  -> try {[],[X]} = om_parse:expr(P,read(P,name(mode(),P,F)),[]), X catch E:R ->
               mad:info("ERROR: ~p~nfile: ~tp~n~tp~n",[F,erlang:get_stacktrace(),R]),
               {error,{"om:parse1",F,R}} end.

% system functions

main(A)     -> mad:main(A).
start()     -> start(normal,[]).
start(_,_)  -> supervisor:start_link({local,om},om,[]).
stop(_)     -> ok.
init([])    -> mode("normal"), {ok, {{one_for_one, 5, 10}, []}}.

% test suite

typed(X)    -> try Y = om:type(X), {Y,[]} catch E:R -> {X,typed} end.
parsed(F)   -> case parse(tname(F),cname(F)) of {error,R} -> {F,parsed}; X -> {X,[]} end.
erased(X)   -> try A = om:erase(X), {A,[]} catch E:R -> {X,erased} end.
pipe(L)     -> lists:foldl(fun(X,{A,D}) -> {N,E}=?MODULE:X(A), {N,[E|D]} end,{L,[]},[parsed,typed]).
pass(true)  -> 'PASSED';
pass(false) -> 'FAILED'.
all()       -> lists:flatten([ begin om:mode(M), om:scan() end || M <- modes() ]).
syscard()   -> [ {F} || F <- filelib:wildcard(name(mode(),"**","*")), filelib:is_dir(F) /= true ].
wildcard()  -> lists:flatten([ {A} || {A,B} <- ets:tab2list(filesystem),
               lists:sublist(A,length(om:priv(mode()))) == om:priv(mode()) ]).
scan()      -> Res = [ { flat(element(2,pipe(F))),F} || {F} <- lists:umerge(wildcard(),syscard()) ],
               Passed = lists:all(fun({X,B}) -> X == [] end, Res),
               {mode(),pass(Passed),Res}.

% relying functions

rev(X)       -> lists:reverse(X).
flat(X)      -> lists:flatten(X).
tokens(X,Y)  -> string:tokens(X,Y).
debug(S,A)   -> case om:debug() of true -> io:format(S,A); false -> ok end.
atom(X)      -> list_to_atom(cat(X)).
cat(X)       -> lists:concat([X]).
last(X)      -> lists:last(X).

file(F) -> case file:read_file(F) of
                {ok,Bin} -> Bin;
                {error,_} -> mad(F) end.

mad(F)  -> case mad_repl:load_file(F) of
                {ok,Bin} -> Bin;
                {error,_} -> <<>> end.
