%%%-------------------------------------------------------------------
%%% @copyright (C) 2021, Aeternity Anstalt
%%%-------------------------------------------------------------------

-module(swagger_endpoints_tests).

-include_lib("eunit/include/eunit.hrl").

-define(OAS2, "2.0").
-define(OAS3, "3.0.0").

-define(TEST_MODULE, swagger_endpoints).

from_yaml_test_() ->
    {foreach,
      fun() ->
          application:start(yamerl)
      end,
      fun(_) ->
          application:stop(yamerl)
      end,
     [ {"Parses single definition", fun parses_single_definition/0}
     , {"Parses various definitions", fun parses_definitions/0}
     , {"Parses single endpoint and a definition", fun parses_single_endpoint/0}
     , {"Parses complex scenario", fun parses_complex_scenario/0}
     , {"Parses swagger.yaml from aeternity/aeternity", fun parses_swagger_yaml/0}
      ]}.

parses_single_definition() ->
    Gen =
        fun(Vsn) ->
            #{ swagger => Vsn
             , paths => []
             , definitions => [d_uint()]}
        end,
    Expected =
        fun(OASVersion) ->
            D = definitions(OASVersion),
            {[ {D ++ "UInt", #{<<"minimum">> => 0, <<"type">> => <<"integer">>}}
            ], #{}, D}
      end,
    V2Yaml = yaml(Gen(?OAS2)),
    V2Expected = Expected(?OAS2),
    V2Expected = ?TEST_MODULE:from_yaml(V2Yaml, []),
    V3Yaml = yaml(Gen(?OAS3)),
    V3Expected = Expected(?OAS3),
    V3Expected = ?TEST_MODULE:from_yaml(V3Yaml, []).

parses_definitions() ->
    Gen =
        fun(Vsn) ->
            #{ swagger => Vsn
             , paths => [
                        ]
             , definitions => [d_uint(), d_uint16(), d_uint32(), d_uint64(), d_txblockheight(),
                               d_encodedhash(), d_encodedpubkey(), d_encodedbytearray(),
                               d_error(),
                               d_pow(Vsn),
                               d_keyblock(Vsn)
                             ]}
        end,
    Expected =
        fun(OASVersion) ->
            D = definitions(OASVersion),
            B = list_to_binary(D),
            {[{D ++ "KeyBlock", #{<<"properties">> => #{<<"beneficiary">> => #{<<"$ref">> => <<B/binary, "EncodedPubkey">>},
                                                        <<"hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"height">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"info">> => #{<<"$ref">> => <<B/binary, "EncodedByteArray">>},
                                                        <<"miner">> => #{<<"$ref">> => <<B/binary, "EncodedPubkey">>},
                                                        <<"nonce">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"pow">> => #{<<"$ref">> => <<B/binary, "Pow">>},
                                                        <<"prev_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"prev_key_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"state_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"target">> => #{<<"$ref">> => <<B/binary, "UInt32">>},
                                                        <<"time">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"version">> => #{<<"$ref">> => <<B/binary, "UInt32">>}},
                                  <<"required">> => [<<"beneficiary">>,<<"hash">>, <<"height">>,<<"info">>,<<"miner">>,
                                                     <<"nonce">>,<<"pow">>,<<"prev_hash">>, <<"prev_key_hash">>,<<"state_hash">>,
                                                     <<"target">>,<<"time">>,<<"version">>],
                                  <<"type">> => <<"object">>}},
              {D ++ "Pow", #{<<"items">> => #{<<"$ref">> => <<B/binary, "UInt32">>}, <<"maxItems">> => 42, <<"minItems">> => 42, <<"type">> => <<"array">>}},
              {D ++ "Error", #{<<"properties">> => #{<<"reason">> => #{<<"type">> => <<"string">>}}, <<"required">> => [<<"reason">>], <<"type">> => <<"object">>}},
              {D ++ "EncodedByteArray", #{<<"description">> => <<"Base64Check encoded tagged byte array">>, <<"type">> => <<"string">>}},
              {D ++ "EncodedPubkey", #{<<"description">> => <<"Base58Check encoded tagged pubkey">>, <<"type">> => <<"string">>}},
              {D ++ "EncodedHash", #{<<"description">> => <<"Base58Check encoded tagged hash">>, <<"type">> => <<"string">>}},
              {D ++ "TxBlockHeight", #{<<"maximum">> => 18446744073709551615, <<"minimum">> => -1, <<"type">> => <<"integer">>}},
              {D ++ "UInt64", #{<<"maximum">> => 18446744073709551615, <<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt32", #{<<"maximum">> => 4294967295, <<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt16", #{<<"maximum">> => 65535,<<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt", #{<<"minimum">> => 0, <<"type">> => <<"integer">>}}
            ], #{}, D}
      end,
    V2Yaml = yaml(Gen(?OAS2)),
    V2Expected = Expected(?OAS2),
    V2Expected = ?TEST_MODULE:from_yaml(V2Yaml, []),
    V3Yaml = yaml(Gen(?OAS3)),
    V3Expected = Expected(?OAS3),
    V3Expected = ?TEST_MODULE:from_yaml(V3Yaml, []).

parses_single_endpoint() ->
    Gen =
        fun(Vsn) ->
            #{ swagger => Vsn
             , paths => [req_current_keyblock_height(Vsn)]
             , definitions => [d_uint()]}
        end,
    Expected =
        fun(OASVersion) ->
            D = definitions(OASVersion),
            B = list_to_binary(D),
            {[ {D ++ "UInt", #{<<"minimum">> => 0, <<"type">> => <<"integer">>}}
            ],
             #{'GetCurrentKeyBlockHeight' =>
                #{get => #{parameters => [], path => <<"/v2/key-blocks/current/height">>,
                           responses => #{200 => #{<<"properties">> => #{<<"height">> => #{<<"$ref">> => <<B/binary, "UInt16">>, <<"description">> => <<"Height">>}}, <<"type">> => <<"object">>},
                                          404 => #{<<"$ref">> => <<B/binary, "Error">>}},
                            tags => [<<"external">>,<<"chain">>]}}}, D}
      end,
    V2Yaml = yaml(Gen(?OAS2)),
    V2Expected = Expected(?OAS2),
    V2Expected = ?TEST_MODULE:from_yaml(V2Yaml, []),
    V3Yaml = yaml(Gen(?OAS3)),
    V3Expected = Expected(?OAS3),
    V3Expected = ?TEST_MODULE:from_yaml(V3Yaml, []),
    ok.


try_v3() ->
    Gen =
        fun(Vsn) ->
            #{ swagger => Vsn
             , paths => [ req_current_keyblock_height(Vsn)
                        , req_get_current_keyblock(Vsn)
                        , req_get_keyblock_by_hash(Vsn)
                        , req_post_keyblock(Vsn)
                        ]
             , definitions => [d_uint(), d_uint16(), d_uint32(), d_uint64(), d_txblockheight(),
                               d_encodedhash(), d_encodedpubkey(), d_encodedbytearray(),
                               d_error(),
                               d_pow(Vsn),
                               d_keyblock(Vsn)
                             ]}
        end,
    V3Yaml = yaml(Gen(?OAS2)),
    ?TEST_MODULE:from_yaml(V3Yaml, []).

parses_complex_scenario() ->
    Gen =
        fun(Vsn) ->
            #{ swagger => Vsn
             , paths => [ req_current_keyblock_height(Vsn)
                        , req_get_current_keyblock(Vsn)
                        , req_get_keyblock_by_hash(Vsn)
                        , req_post_keyblock(Vsn)
                        ]
             , definitions => [d_uint(), d_uint16(), d_uint32(), d_uint64(), d_txblockheight(),
                               d_encodedhash(), d_encodedpubkey(), d_encodedbytearray(),
                               d_error(),
                               d_pow(Vsn),
                               d_keyblock(Vsn)
                             ]}
        end,
    Expected =
        fun(OASVersion) ->
            D = definitions(OASVersion),
            B = list_to_binary(D),
            {[{D ++ "KeyBlock", #{<<"properties">> => #{<<"beneficiary">> => #{<<"$ref">> => <<B/binary, "EncodedPubkey">>},
                                                        <<"hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"height">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"info">> => #{<<"$ref">> => <<B/binary, "EncodedByteArray">>},
                                                        <<"miner">> => #{<<"$ref">> => <<B/binary, "EncodedPubkey">>},
                                                        <<"nonce">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"pow">> => #{<<"$ref">> => <<B/binary, "Pow">>},
                                                        <<"prev_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"prev_key_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"state_hash">> => #{<<"$ref">> => <<B/binary, "EncodedHash">>},
                                                        <<"target">> => #{<<"$ref">> => <<B/binary, "UInt32">>},
                                                        <<"time">> => #{<<"$ref">> => <<B/binary, "UInt64">>},
                                                        <<"version">> => #{<<"$ref">> => <<B/binary, "UInt32">>}},
                                  <<"required">> => [<<"beneficiary">>,<<"hash">>, <<"height">>,<<"info">>,<<"miner">>,
                                                     <<"nonce">>,<<"pow">>,<<"prev_hash">>, <<"prev_key_hash">>,<<"state_hash">>,
                                                     <<"target">>,<<"time">>,<<"version">>],
                                  <<"type">> => <<"object">>}},
              {D ++ "Pow", #{<<"items">> => #{<<"$ref">> => <<B/binary, "UInt32">>}, <<"maxItems">> => 42, <<"minItems">> => 42, <<"type">> => <<"array">>}},
              {D ++ "Error", #{<<"properties">> => #{<<"reason">> => #{<<"type">> => <<"string">>}}, <<"required">> => [<<"reason">>], <<"type">> => <<"object">>}},
              {D ++ "EncodedByteArray", #{<<"description">> => <<"Base64Check encoded tagged byte array">>, <<"type">> => <<"string">>}},
              {D ++ "EncodedPubkey", #{<<"description">> => <<"Base58Check encoded tagged pubkey">>, <<"type">> => <<"string">>}},
              {D ++ "EncodedHash", #{<<"description">> => <<"Base58Check encoded tagged hash">>, <<"type">> => <<"string">>}},
              {D ++ "TxBlockHeight", #{<<"maximum">> => 18446744073709551615, <<"minimum">> => -1, <<"type">> => <<"integer">>}},
              {D ++ "UInt64", #{<<"maximum">> => 18446744073709551615, <<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt32", #{<<"maximum">> => 4294967295, <<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt16", #{<<"maximum">> => 65535,<<"minimum">> => 0, <<"type">> => <<"integer">>}},
              {D ++ "UInt", #{<<"minimum">> => 0, <<"type">> => <<"integer">>}}
            ],
            #{'GetCurrentKeyBlock' => #{get => #{parameters => [], path => <<"/v2/key-blocks/current">>,
                                                responses => #{200 => #{<<"$ref">> => <<B/binary, "KeyBlock">>}, 404 => #{<<"$ref">> => <<B/binary, "Error">>}},
                                                tags => [<<"external">>,<<"chain">>]}},
            'GetCurrentKeyBlockHeight' => #{get => #{parameters => [], path => <<"/v2/key-blocks/current/height">>,
                                                      responses => #{200 => #{<<"properties">> => #{<<"height">> => #{<<"$ref">> => <<B/binary, "UInt16">>, <<"description">> => <<"Height">>}}, <<"type">> => <<"object">>},
                                                                    404 => #{<<"$ref">> => <<B/binary, "Error">>}},
                                                      tags => [<<"external">>,<<"chain">>]}},
            'GetKeyBlockByHash' => #{get => #{parameters => [[{"in","path"}, {"name","hash"}, {"description", "The hash of the block"}, {"required",true}, {"type","string"}]], path => <<"/v2/key-blocks/hash/{hash}">>,
                                              responses => #{200 => #{<<"$ref">> => <<B/binary, "KeyBlock">>},
                                                             400 => #{<<"$ref">> => <<B/binary, "Error">>},
                                                             404 => #{<<"$ref">> => <<B/binary, "Error">>}},
                                              tags => [<<"external">>, <<"chain">>]}},
            'PostKeyBlock' => #{post => #{parameters => [[{"in","body"},
                                                          {"name","body"},
                                                          {"description", "Mined key block"},
                                                          {"required",true}, {"schema", #{<<"$ref">> => <<B/binary, "KeyBlock">>}}]], path => <<"/v2/key-blocks">>,
                                          responses => #{200 => undefined, 400 => #{<<"$ref">> => <<B/binary, "Error">>}},
                                          tags => [<<"internal">>, <<"chain">>]}}
             },
             D
          }
      end,
    V2Yaml = yaml(Gen(?OAS2)),
    V2Expected = Expected(?OAS2),
    V2Expected = ?TEST_MODULE:from_yaml(V2Yaml, []),
    V3Yaml = yaml(Gen(?OAS3)),
    V3Expected = Expected(?OAS3),
    V3Expected = ?TEST_MODULE:from_yaml(V3Yaml, []).

parses_swagger_yaml() ->
    [V2Yaml] = yamerl_constr:file("test/swagger_v2.yaml"),
    {_V2Defs, _V2, _} = swagger_endpoints:from_yaml(V2Yaml, []),
    [V3Yaml] = yamerl_constr:file("test/swagger_v3.yaml"),
    {_V3Defs, V3, _V3Prefix} = swagger_endpoints:from_yaml(V3Yaml, []),
    %% ensure we've parsed the param from #/components/parameters/
    #{get := #{parameters := [[{"in","query"},
                               {"name","big-int-as-string"},
                               {"description",
                               "If this flag is set to true, the response will have all integers set as strings"},
                               {"required",false},
                               {"type","boolean"}]]}} = maps:get('GetTopBlock', V3),
    ok.

yaml(Opts) ->
    G = fun(K, Def) -> maps:get(K, Opts, Def) end,
    OASVersion = G(swagger, ?OAS2),
    Tags =
        multiline(lists:map(
            fun({Name, Descr}) ->
                multiline([ "  - name: " ++ Name
                          , "    description: " ++ Descr])
            end,
            G(tags, [ {"external", "External API"}
                    , {"internal", "Internal API"}
                    , {"chain", "Chain related endpoints"}
                    , {"transaction", "Transaction related endpoints"}
                    ]))),
    Schemes =
        multiline(lists:map(
            fun(Scheme) -> "  - " ++ Scheme end, G(schemes, ["http"]))),
    Paths1 =
        multiline(lists:map(
            fun({URL, Methods}) ->
                EncMethods =
                    multiline(lists:map(
                        fun(M) -> encode_method(M, OASVersion) end,
                        Methods)),
                multiline(
                    [ "  " ++ URL ++ ":"
                    , EncMethods])
            end,
            G(paths, []))),
    Paths =
        case length(Paths1) =:= 0 of
            true ->  "paths: []";
            false -> "paths:\n" ++ Paths1
        end,
    Definitions =
        multiline(lists:map(fun(D) -> enc_definition(D, OASVersion) end, G(definitions, []))),
    Str =
        case OASVersion of
            ?OAS2 ->
                multiline(
                    [ "swagger: '" ++ OASVersion ++ "'"
                    , "info:"
                    , "  description: '" ++ G(description, "This is the [Aeternity](https://www.aeternity.com/) node API.") ++ "'"
                    , "  version: " ++ G(version, "x.y.z")
                    , "  title: " ++ G(title, "Aeternity node")
                    , "  termsOfService: '" ++ G(tos, "https://www.aeternity.com/terms/") ++ "'"
                    , "  contact:"
                    , "    email: " ++ G(email, "apiteam@aeternity.com")
                    , "basePath: " ++ G(basePath, "/v2")
                    , "tags:\n" ++ Tags
                    , "schemes:\n" ++ Schemes 
                    , Paths
                    , "definitions:\n" ++ Definitions
                    ]);
            ?OAS3 ->
                multiline(
                    [ "openapi: '" ++ OASVersion ++ "'"
                    , "info:"
                    , "  description: '" ++ G(description, "This is the [Aeternity](https://www.aeternity.com/) node API.") ++ "'"
                    , "  version: " ++ G(version, "x.y.z")
                    , "  title: " ++ G(title, "Aeternity node")
                    , "  termsOfService: '" ++ G(tos, "https://www.aeternity.com/terms/") ++ "'"
                    , "  contact:"
                    , "    email: " ++ G(email, "apiteam@aeternity.com")
                    , "servers: "
                    , "  - url: " ++ G(basePath, "/v2")
                    , "tags:\n" ++ Tags
                    , Paths
                    , "components:"
                    , "  schemas:\n"++ Definitions
                    ])
        end,
%%    1 = Str,
    [Yaml] =yamerl_constr:string(Str),
    Yaml.

multiline(L) -> lists:concat(lists:join("\n", lists:filter(fun(E) -> E =/= skip end, L))). 

encode_method({Method, #{ tags            := Tags0
                        , operationid     := OperationId
                        , description     := Description
                        , req_parameters  := ReqParameters
                        , responses       := Responses0}},
              OASVersion) ->
    Tags =
        multiline(lists:map(
            fun(T) -> "        - " ++ T end, Tags0)),
    {Parameters1, Body1} = make_req_params(ReqParameters, OASVersion),
    Parameters =
        case length(Parameters1) =:= 0 of
            true ->  "      parameters: []";
            false -> "      parameters:\n" ++ Parameters1
        end,
    Body =
        case length(Body1) =:= 0 of
            true -> skip;
            false ->
                case OASVersion of %% OAS2 is handled in params
                    ?OAS3 ->
                        "      requestBody:\n" ++ Body1
                end
        end,
    Responses =
        multiline(lists:map(
            fun({Code, #{ description := RespDesr
                        , schema := Schema}}) ->
                MaybeSchema =
                    fun(Str, Prefix) ->
                        case Schema =:= none of
                            true -> skip;
                            false -> Str ++ encode_schema(Schema, Prefix)
                        end
                    end,
                case OASVersion of
                    ?OAS2 ->
                        multiline(
                            [ "        '" ++ integer_to_list(Code) ++ "':"
                            , "          description: '" ++ RespDesr ++ "'" 
                            , MaybeSchema("          schema:\n", "")]);
                    ?OAS3 ->
                        multiline(
                            [ "        '" ++ integer_to_list(Code) ++ "':"
                            , "          description: '" ++ RespDesr ++ "'" 
                            , MaybeSchema(multiline([ "          content:\n"
                                                    , "            application/json:\n"
                                                    , "              schema:\n"]), "    ")])
                end
            end,
            Responses0)),
    MaybeProduces =
        case OASVersion of
            ?OAS2 ->
                "      produces:\n" ++
                "        - application/json";
            ?OAS3 -> skip
        end,
    multiline(
        [ "    " ++ Method ++ ":"
        , "      tags:\n" ++ Tags
        , "      operationId: " ++ OperationId
        , "      description: '" ++ Description ++ "'"
        , MaybeProduces
        , Parameters
        , Body
        , "      responses:\n" ++ Responses]).


encode_schema({ref, Ref}, Prefix) ->
    Prefix ++ "            $ref: '" ++ Ref ++ "'";
encode_schema({object, Properties0}, Prefix) ->
    Properties =
        multiline(lists:map(
            fun({Name, #{ description := Descr
                        , ref := Ref}}) ->
                multiline(
                    [ Prefix ++ "              " ++ Name ++ ":"
                    , Prefix ++ "                description: '" ++ Descr ++ "'"
                    , Prefix ++ "                $ref: '" ++ Ref ++ "'"])
            end,
            Properties0)),
    multiline(
        [ Prefix ++ "            type: object"
        , Prefix ++ "            properties:\n" ++ Properties]).

enc_definition(Spec, OASVersion) ->
    VPrefix =
        case OASVersion of
            ?OAS2 -> "";
            ?OAS3 -> "  "
        end,
    GetOptionals =
        fun(Keys, Opts) ->
              lists:filtermap(
                  fun(Key) ->
                      case maps:find(Key, Opts) of
                          {ok, Val} when is_integer(Val) -> {true, VPrefix ++ "    " ++ atom_to_list(Key) ++ ": " ++ integer_to_list(Val)};
                          {ok, Val} when is_list(Val)    -> {true, VPrefix ++ "    " ++ atom_to_list(Key) ++ ": '" ++ Val ++ "'"};
                          error -> false
                      end
                  end,
                  Keys) end,
    case Spec of
        {Name, Type, Opts} when Type =:= integer;
                                Type =:= string ->
            Optionals = GetOptionals([minimum, maximum, description], Opts),
            multiline(
              [ VPrefix ++ "  " ++ Name ++ ":"
              , VPrefix ++ "    type: " ++ atom_to_list(Type)
              ] ++ Optionals);
        {Name, array, Ref, Opts} ->
            Optionals = GetOptionals([minItems, maxItems, description], Opts),
            multiline(
              [ VPrefix ++ "  " ++ Name ++ ":"
              , VPrefix ++ "    type: array"
              , VPrefix ++ "    items:"
              , VPrefix ++ "      $ref: '" ++ Ref ++ "'"
              ] ++ Optionals);
        {Name, object, Properties0, Required0, Opts} ->
            Optionals = GetOptionals([description], Opts),
            Properties =
                multiline(lists:map(
                    fun({K, Ref}) when is_list(Ref) ->
                        VPrefix ++ "      " ++ atom_to_list(K) ++ ":\n" ++
                        VPrefix ++ "        $ref: '" ++ Ref ++ "'";
                      ({K, Type}) when Type =:= integer; Type =:= string ->
                        VPrefix ++ "      " ++ atom_to_list(K) ++ ":\n" ++
                        VPrefix ++ "        type: " ++ atom_to_list(Type)
                    end,
                    maps:to_list(Properties0))),
            Required = 
                multiline(lists:map(
                    fun(K) -> VPrefix ++ "      - " ++ atom_to_list(K) end,
                    Required0)),
            multiline(
              [ VPrefix ++ "  " ++ Name ++ ":"
              , VPrefix ++ "    type: object"
              , VPrefix ++ "    properties:\n" ++ Properties
              , VPrefix ++ "    required:\n" ++ Required 
              ] ++ Optionals)
    end.

request_method(Method, Tags, OperationId, Description, ReqParams, Responses) ->
    {Method, #{ tags            => Tags
              , operationid     => OperationId
              , description     => Description
              , req_parameters  => ReqParams
              , responses       => Responses}}.

response(Code, Desc, Schema) ->
    {Code, #{description => Desc, schema => Schema}}.

req_current_keyblock_height(OASVersion) ->
    Resp =
        {object, [{"height",
                    #{ description => "Height"
                    , ref => "#" ++ definitions(OASVersion) ++ "UInt16"}}]},
    Get =
        request_method("get", ["external", "chain"],
                      "GetCurrentKeyBlockHeight", "Get the height of the current key block",
                      #{}, [success_response(Resp),
                           error_response(404, "Block not found", OASVersion)]),
    {"/key-blocks/current/height", [Get]}.

req_get_current_keyblock(OASVersion) ->
    Get =
        request_method("get", ["external", "chain"],
                      "GetCurrentKeyBlock", "Get the current key block",
                      #{}, [success_response({ref, "#" ++ definitions(OASVersion) ++ "KeyBlock"}),
                           error_response(404, "Block not found", OASVersion)]),
    {"/key-blocks/current", [Get]}.

req_get_keyblock_by_hash(OASVersion) ->
    Params =
        [#{ in => "path"
          , name => "hash"
          , description => "The hash of the block"
          , required => "true" 
          , type => "string" }],
    Get =
        request_method("get", ["external", "chain"],
                      "GetKeyBlockByHash", "Get a key block by hash",
                      #{params => Params},
                      [ success_response({ref, "#" ++ definitions(OASVersion) ++ "KeyBlock"}),
                        error_response(404, "Block not found", OASVersion),
                        error_response(400, "Invalid hash", OASVersion)]),
    {"/key-blocks/hash/{hash}", [Get]}.

req_post_keyblock(OASVersion) ->
    Body =
        [#{ in => "body"
          , name => "body"
          , description => "Mined key block"
          , required => "true" 
          , ref => definitions(OASVersion) ++ "KeyBlock" }],
    Post =
        request_method("post", ["internal", "chain"],
                      "PostKeyBlock", "Post a mined key block",
                      #{body => Body},
                      [ success_response(none),
                        error_response(400, "Invalid block", OASVersion)]),
    {"/key-blocks", [Post]}.
    
success_response(RespObj) ->
    response(200, "Successful operation", RespObj).

error_response(Code, Description, OASVersion) ->
    response(Code, Description, {ref, "#" ++ definitions(OASVersion) ++ "Error"}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
d_uint() ->
    {"UInt", integer, #{minimum => 0}}.

d_uint16() ->
    {"UInt16", integer, #{minimum => 0, maximum => 65535}}.

d_uint32() ->
    {"UInt32", integer, #{minimum => 0, maximum => 4294967295}}.

d_uint64() ->
    {"UInt64", integer, #{minimum => 0, maximum => 18446744073709551615}}.

d_txblockheight() ->
    {"TxBlockHeight", integer, #{minimum => -1, maximum => 18446744073709551615}}.

d_encodedhash() ->
    {"EncodedHash", string, #{description => "Base58Check encoded tagged hash"}}.

d_encodedpubkey() ->
    {"EncodedPubkey", string, #{description => "Base58Check encoded tagged pubkey"}}.

d_encodedbytearray() ->
    {"EncodedByteArray", string, #{description => "Base64Check encoded tagged byte array"}}.

d_pow(OASVersion) ->
    {"Pow", array, "#" ++ definitions(OASVersion) ++ "UInt32", #{minItems => 42, maxItems => 42}}.

d_error() ->
    {"Error", object, #{reason => string}, [reason], #{}}.

d_keyblock(OASVersion) ->
    Properties = #{ hash => "#" ++ definitions(OASVersion) ++ "EncodedHash"
                  , height => "#" ++ definitions(OASVersion) ++ "UInt64"
                  , prev_hash => "#" ++ definitions(OASVersion) ++ "EncodedHash"
                  , prev_key_hash => "#" ++ definitions(OASVersion) ++ "EncodedHash"
                  , state_hash => "#" ++ definitions(OASVersion) ++ "EncodedHash"
                  , miner => "#" ++ definitions(OASVersion) ++ "EncodedPubkey"
                  , beneficiary => "#" ++ definitions(OASVersion) ++ "EncodedPubkey"
                  , target => "#" ++ definitions(OASVersion) ++ "UInt32"
                  , pow => "#" ++ definitions(OASVersion) ++ "Pow"
                  , nonce => "#" ++ definitions(OASVersion) ++ "UInt64"
                  , time => "#" ++ definitions(OASVersion) ++ "UInt64"
                  , version => "#" ++ definitions(OASVersion) ++ "UInt32"
                  , info => "#" ++ definitions(OASVersion) ++ "EncodedByteArray"},
    Required = maps:keys(Properties),
    {"KeyBlock", object, Properties, Required, #{}}.

definitions(?OAS2) -> "/definitions/";
definitions(?OAS3) -> "/components/schemas/".

make_req_params(ReqParams, ?OAS2) ->
    Params0 = maps:get(params, ReqParams, []) ++ maps:get(body, ReqParams, []),
    Params =
        multiline(lists:map(
            fun(#{ in := In
                  , name := Name
                  , description := ParamDesr
                  , required := Required
                  } = P) ->
              Type =
                  case P of
                      #{ type := T } ->
                              "          type: " ++ T;
                      #{ ref := Ref } ->
                              "          schema:\n"
                              "            $ref: '" ++ Ref ++ "'"
                  end,
                multiline(
                    [ "        - in: " ++ In
                    , "          name: " ++ Name
                    , "          description: '" ++ ParamDesr ++ "'"
                    , "          required: " ++ Required
                    , Type])
            end,
            Params0)),
    {Params, []};
make_req_params(ReqParams, ?OAS3) ->
    Params = maps:get(params, ReqParams, []),
    Body = maps:get(body, ReqParams, []),
    Parameters1 =
        multiline(lists:map(
            fun(#{ in := In
                 , name := Name
                 , description := ParamDesr
                 , required := Required
                 , type := Type
                 }) ->
                multiline(
                    [ "        - in: " ++ In
                    , "          name: " ++ Name
                    , "          description: '" ++ ParamDesr ++ "'"
                    , "          required: " ++ Required
                    , "          schema:\n"
                    , "            type: " ++ Type])
              end,
            Params)),
      ReqBody =
          multiline(lists:map(
              fun(#{ in := "body"
                  , description := ParamDesr
                  , required := Required
                  } = P) ->
                  Type =
                      case P of
                          #{ type := T } ->
                              "              type: " ++ T;
                          #{ ref := Ref } ->
                              "              $ref: '" ++ Ref ++ "'"
                      end,
                  multiline([
                      "        content: "
                    , "          application/json:"
                    , "            schema:"
                    , Type
                    , "        description: '" ++ ParamDesr ++ "'"
                    , "        required: " ++ Required
                            ])
              end,
              Body)),
      {Parameters1, ReqBody}.

