-module(swagger_endpoints).

-export([init/1, from_yaml/2]).

-define(OAS2, "2.0").
-define(OAS3, "3.0.0").

%% Yaml parser outputs strings (list of characters).
%% Both jsx and jesse expect eitehr atoms or binaries
%% This causes additional code to transform these strings to binaries.

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
  application:ensure_started(yamerl),
  {ok, State1} = swagger_endpoints_prv:init(State),
  {ok, State1}.

from_yaml(Doc, Options0) ->
  OASVersion    = get_version(Doc),
  BaseUri =
      case OASVersion of
          ?OAS2 -> proplists:get_value("basePath", Doc, "/");
          ?OAS3 ->
              [[{"url", Prefix}]] = proplists:get_value("servers", Doc, [[{"url", "/"}]]),
              Prefix
      end,
  Endpoints = proplists:get_value("paths", Doc, []),
  Definitions0 = 
      case OASVersion of
          ?OAS2 -> proplists:get_value("definitions", Doc, []);
          ?OAS3 ->
              Components = proplists:get_value("components", Doc, []),
              proplists:get_value("schemas", Components, [])
      end,
  Parameters   =
    case OASVersion of
      ?OAS2 -> proplists:get_value("parameters", Doc, []);
      ?OAS3 ->
        Cs = proplists:get_value("components", Doc, []),
        proplists:get_value("parameters", Cs, [])
    end,
  Definitions  = build_definitions(Definitions0, [], Options0, OASVersion),
  Options      = [{params, Parameters}, {defs, Definitions}, {baseuri, BaseUri} | Options0],
  {Definitions, endpoint_map(Endpoints,  #{}, Options, OASVersion), definitions_prefix(OASVersion)}.

build_definitions([], Definitions, _Options, _OASVersion) ->
  Definitions;
build_definitions([{Def, Schema} | Defs], Definitions, Options, OASVersion) ->
  Prefix = definitions_prefix(OASVersion),
  NewDef = {Prefix ++ Def, to_json_schema(Schema, [{defs, Definitions}|Options])},
  build_definitions(Defs, [NewDef | Definitions], Options, OASVersion).

endpoint_map([], Map, _Options, _OASVersion) ->
  Map;
endpoint_map([{Path, EP}|EPs], Map, Options, OASVersion) ->
  {Key, Value} = method_part(Path, EP, Options, OASVersion),
  endpoint_map(EPs, maps:put(Key, Value, Map), Options, OASVersion).


method_part(Path, EP, Options, OASVersion) ->
  case {lists:keyfind("post", 1, EP),
        lists:keyfind("get", 1, EP)} of
    {{"post", Attr}, false} ->
      mk_operation(Path, Attr, post, Options, OASVersion);
    {false, {"get", Attr}} ->
      mk_operation(Path, Attr, get, Options, OASVersion);
    {true, true} ->
      throw({error, "use either method POST or GET in", Path});
    {false, false} ->
      throw({error, "need method POST or GET in", Path})
  end.

mk_operation(Path, Attr, Method, Options, OASVersion) ->
  BaseUri =
    iolist_to_binary(string:trim(proplists:get_value(baseuri, Options, "/"), trailing, "/")),
  BPath = iolist_to_binary(Path),
  IdName = get_value("operationId", proplists:get_value(id_type, Options, atom), Attr, Path),
  Tags = get_value("tags", {list, binary}, Attr, Path, []),
  Params = get_value("parameters", {list, string}, Attr, Path, []),
  Body =
    case proplists:get_value("requestBody", Attr, null) of
      null -> [];
      B -> [B]
    end,
  ReadResponse =
    fun({StatusCode, Resp}) ->
      response(StatusCode, Resp, [{path, Path} | Options], OASVersion)
    end,
  Responses =
    maps:from_list(get_value("responses", {list, ReadResponse}, Attr, Path, [])),
  {IdName, #{Method => #{
                path => <<BaseUri/binary, BPath/binary>>,
                tags => Tags,
                parameters => params_to_json_schema(Body ++  Params, [{endpoint, IdName} | Options], OASVersion),
                responses  => Responses
              }}}.

get_value(Name, Type, Attr, Path) ->
  get_value(Name, Type, Attr, Path, undefined).

get_value(Name, Type, Attr, Path, Default) ->
  case proplists:get_value(Name, Attr, Default) of
    undefined ->
      throw({error, "no " ++ Name ++ " provided", Path});
    %% if a key is present but has no elements in it - the value is null
    null when element(1, Type) =:= list ->
      Default;
    Val ->
      Parse =
        fun(T, V) ->
          case T of
            atom -> list_to_atom(V);
            binary -> iolist_to_binary(V);
            string -> V;
            F when is_function(F, 1) -> F(V)
          end
        end,
      case Type of
        {list, ElType} ->
          lists:map(fun(Element) -> Parse(ElType, Element) end, Val);
          _ -> Parse(Type, Val)
      end
   end.

response(StatusCode, Resp, Options, OASVersion) ->
  StrictCompilation = proplists:get_value(strict, Options, false),
  Code =
    try {SC, []} = string:to_integer(StatusCode), SC
    catch
      _:_ ->
        rebar_api:error("Response status code for path ~p cannot be parsed (~p, ~p)",
                        [ proplists:get_value(path, Options), StatusCode, Resp])
    end,
  YamlSchema =
      case OASVersion of
          ?OAS2 -> proplists:get_value("schema", Resp);
          ?OAS3 ->
            Content = proplists:get_value("content", Resp, []),
            JSON = proplists:get_value("application/json", Content, []),
            proplists:get_value("schema", JSON)
      end,
  case YamlSchema of
    undefined when StrictCompilation ->
      rebar_api:warn("Empty response body for path ~p (~p, ~p)",
                     [ proplists:get_value(path, Options), StatusCode, Resp]),
      {Code, undefined};
    undefined -> {Code, undefined};
    Yaml    ->
      Schema = (catch to_json_schema(Yaml, Options)),
      {Code, Schema}
  end .

params_to_json_schema(Params, Options, OASVersion) ->
  [ case proplists:get_value("$ref", Param, none) of
      none ->
        case proplists:get_value("schema", Param, none) of
          none when OASVersion =:= ?OAS2 -> 
            Param;
          Schema when OASVersion =:= ?OAS2-> %% [{"$ref", Ref}]
            lists:keydelete("schema", 1, Param) ++ [{"schema", to_json_schema(Schema, Options)}];
          Schema when is_list(Schema), OASVersion =:= ?OAS3-> %% [{"type", "integer" | "string"}]
            lists:keydelete("schema", 1, Param) ++ Schema;
          none when OASVersion =:= ?OAS3 ->
            case proplists:get_value("content", Param, none) of
                none -> Param;
                [{_ContentType, [{"schema", [{"$ref", _Ref}] = Schema}]}] ->
                  [{"in", "body"}, {"name", "body"}] ++
                  lists:keydelete("content", 1, Param) ++ [{"schema", to_json_schema(Schema, Options)}]
            end
        end;
      ParamPath when is_list(ParamPath) ->
        Ref =
            case ParamPath of
              "#/parameters/" ++ R0 when OASVersion =:= ?OAS2 -> R0;
              "#/components/parameters/" ++ R0 when OASVersion =:= ?OAS3 -> R0
            end,
        ParamRefs = proplists:get_value(params, Options, []),
        case lists:keyfind(Ref, 1, ParamRefs) of
          false ->
            rebar_api:error("Undefined parameter $ref: ~p\n", [Ref]);
          {Ref, InlineParams} ->
            InlineParams
        end
    end || Param <- Params ].

to_json_schema(Schema, Options) ->
  %% Turn Yaml into a map with binaries as keys
  Result = jesse_json_schema(Schema, Options),
  rebar_api:debug("translating ~p into ~p", [Schema, Result]),
  Result.

jesse_json_schema(Schema, Options) when is_list(Schema) ->
  lists:foldl(fun(Item, Acc) ->
                  maps:merge(to_json_schema(Item, Options), Acc)
              end, #{}, Schema);
jesse_json_schema({"$ref", Reference}, _Options) ->
  DefRef = string:trim(Reference, leading, "#"),
  #{<<"$ref">> => list_to_binary(DefRef)};
jesse_json_schema({Key, Items}, _Options) when Key == "required"; Key == "enum" ->
  BinKey = list_to_binary(Key),
  #{BinKey => [ list_to_binary(Item) || Item <- Items ]};
jesse_json_schema({Key, Value}, _Options) when
    is_number(Value); is_boolean(Value); is_binary(Value) ->
  BinKey = list_to_binary(Key),
  #{BinKey => Value};
jesse_json_schema({Key, Value}, Options) when is_list(Value) ->
  BinKey = list_to_binary(Key),
  case lists:all(fun(C) -> is_integer(C) andalso C > 0 end, Value) of
    true ->
      #{BinKey => list_to_binary(Value)};
    false ->
      #{BinKey => jesse_json_schema(Value, Options)}
  end;
jesse_json_schema(Schema, _Options) ->
  #{error => Schema}.

get_version(Doc) ->
    case proplists:get_value("swagger", Doc, not_set) of
        ?OAS2 -> ?OAS2;
        not_set ->
            case proplists:get_value("openapi", Doc) of
                ?OAS3 -> ?OAS3
            end
    end.

definitions_prefix(?OAS2) -> "/definitions/";
definitions_prefix(?OAS3) -> "/components/schemas/".
