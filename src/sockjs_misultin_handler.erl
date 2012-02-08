-module(sockjs_misultin_handler).

-export([handle_ws/2]).

-include("sockjs_internal.hrl").

%% --------------------------------------------------------------------------
%% TODO: heartbeats
%% TODO: infinity as delay

handle_ws(Service, Req) ->
    {RawWebsocket, {misultin, Req2}} =
        case sockjs_handler:get_action(Service, {misultin, Req}) of
            {{match, WS}, Req1} when WS =:= websocket orelse
                                     WS =:= rawwebsocket ->
                {WS, Req1}
        end,
    SessionPid = sockjs_session:maybe_create(undefined, Service#service{
                                                          disconnect_delay=100}),
    self() ! go,
    handle_ws0({Req2, RawWebsocket, SessionPid}).

handle_ws0({_Req, RawWebsocket, SessionPid} = S) ->
    io:format("handle_ws0~n"),
    receive
        go ->
            case ws_loop(go, S) of
                ok       -> handle_ws0(S);
                shutdown -> closed
            end;
        {browser, Data} ->
            Data1 = list_to_binary(Data),
            case sockjs_ws_handler:received(RawWebsocket, SessionPid, Data1) of
                ok       -> handle_ws0(S);
                shutdown -> closed
            end;
        closed ->
            closed
    end.

ws_loop(go, {Req, RawWebsocket, SessionPid}) ->
    case sockjs_ws_handler:reply(RawWebsocket, SessionPid) of
        wait ->
            io:format("ok~n", []),
            ok;
        {ok, Data} ->
            self() ! go,
            io:format("ok send: ~p~n", [Data]),
            Req:send(Data),
            ok;
        {close, <<>>} ->
            shutdown;
        {close, Data} ->
            io:format("close send: ~p~n", [Data]),
            Req:send(Data),
            shutdown
    end.
