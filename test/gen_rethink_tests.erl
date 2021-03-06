-module(gen_rethink_tests).

-compile([export_all]).

-define(AdminUser, #{<<"id">> := <<"admin">>,<<"password">> := false}).

connect_test() ->
    {ok, Re} = gen_rethink:connect(),
    Reql = reql:db(<<"rethinkdb">>),
    reql:hold(Reql),
    reql:table(Reql, <<"users">>),
    reql:filter(Reql, #{<<"password">> => false}),
    ok = fun() ->
        {ok, Cursor} = gen_rethink:run(Re, Reql, 1000),
        {ok,ResultsList} = rethink_cursor:all(Cursor),
        [?AdminUser] = lists:flatten(ResultsList),
        false = is_process_alive(Cursor),
        ok
     end(),
    ok = fun() ->
        {ok, Cursor} = gen_rethink:run(Re, Reql, 1000),
        ok = rethink_cursor:activate(Cursor),
        [?AdminUser] = receive
            {rethink_cursor, Result} ->
                Result
        after 1000 ->
                  []
        end,
        ok = receive
                 {rethink_cursor, done} ->
                     ok
             after 1000 ->
                       error
             end,
        false = is_process_alive(Cursor),
        ok
       end().

user_test() ->
    {ok, Admin} = gen_rethink:connect(),
    NewUsername = <<"rethink_erlang_unit_test">>,
    NewPassword = <<"secret">>,
    NewUser = #{id => NewUsername,
                password => #{password => NewPassword,
                              iterations => 1024}},
    {ok, _} = gen_rethink:run(Admin, fun(X) ->
                                reql:db(X, rethinkdb),
                                reql:table(X, users),
                                reql:insert(X, NewUser)
                        end),
    {ok, Re2} = gen_rethink:connect(#{user => NewUsername,
                                      password => NewPassword}),
    {ok, _} = gen_rethink:run(Re2, fun(X) ->
                                           reql:db_list(X)
                                   end),
    {ok, _} = gen_rethink:run(Admin, fun(X) ->
                                             reql:db(X, rethinkdb),
                                             reql:table(X, users),
                                             reql:get(X, NewUsername),
                                             reql:delete(X)
                                     end),
    gen_rethink:close(Admin),
    gen_rethink:close(Re2).

session_test() ->
    {ok, Session} = gen_rethink_session:start_link(#{}),
    {ok, _} = gen_rethink_session:get_connection(Session).

server_info_test() ->
    {ok, C} = gen_rethink:connect(),
    {ok, _} = gen_rethink:server_info(C),
    gen_rethink:close(C).
