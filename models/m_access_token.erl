-module(m_access_token).
-author("Driebit <tech@driebit.nl>").

-export([
    install/1,
    create/3,
    get/2
]).

-define(TOKEN_TABLE, oauth2_access_token).
-define(TOKEN_TTL, 3600).

-include("zotonic.hrl").

%% @doc Create a new access token for a client and user
create(ClientId, UserId, Context) ->
    Token = generate(),
    case z_db:insert(
        ?TOKEN_TABLE,
        [
            {client_id, z_convert:to_integer(ClientId)},
            {user_id, z_convert:to_integer(UserId)},
            {access_token, Token},
            {expires_at, z_datetime:to_datetime(z_datetime:timestamp() + ?TOKEN_TTL)}
        ],
        Context
    ) of
        {ok, Id} ->
            z_db:assoc_props_row(
                "select client_id, access_token, user_id, expires_at from oauth2_access_token where id=$1",
                [Id],
                Context
            );
        R ->
            ?DEBUG(R)
    end.

%% @doc Retrieve previously created access token
-spec get(string(), #context{}) -> list() | undefined.
get(Token, Context) ->
    z_db:assoc_props_row(
        "select client_id, access_token, user_id, expires_at from oauth2_access_token where access_token=$1",
        [Token],
        Context
    ).

%% @doc Create database tables
install(Context) ->
    case z_db:table_exists(?TOKEN_TABLE, Context) of
        false ->
            [] = z_db:q("
                    create table oauth2_access_token (
                        id serial not null,
                        client_id integer not null,
                        user_id integer,
                        access_token varchar(255) not null,
                        expires_at timestamp with time zone not null default now(),
                        primary key (id)
                    )
                ", Context),
            [] = z_db:q("
                    create index access_token on oauth2_access_token (access_token)
                ", Context),
            ok;
        true ->
            ok
    end.

%% @doc Generate an access token
generate() ->
    base64:encode_to_string(crypto:hash(sha512, crypto:rand_bytes(100))).
