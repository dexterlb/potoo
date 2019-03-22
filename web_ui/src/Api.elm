module Api exposing (Request(..), Response(..), Token, api, subscriptions)

import Contracts exposing (..)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE
import Socket

type alias Token = JE.Value

type Response
    = GotContract Contract
    | GotValue Topic JE.Value
    | CallResult Token JE.Value
    | CallError  Token JE.Value
    | Connected
    | Disconnected
    | Unknown JE.Value

type Request
    = Connect { url: String, root: Topic }
    | Subscribe Topic
    | Call { path: Topic, argument: JE.Value } Token



subscriptions : (Response -> msg) -> Sub msg
subscriptions f = Socket.incoming (f << parseResponse)

api : Request -> Cmd msg
api req = Socket.outgoing <| encodeRequest req

parseResponse : JE.Value -> Response
parseResponse v = JD.decodeValue responseDecoder v
    |> Result.withDefault (Unknown <| JE.object
        [ ("error", JE.string "cannot parse response")
        , ("value", v)
        ])

encodeRequest : Request -> JE.Value
encodeRequest req = case req of
    Connect { url, root } -> JE.object
        [ ("_t", JE.string "connect")
        , ("url", JE.string url)
        , ("root", JE.string root)
        ]
    Subscribe topic -> JE.object
        [ ("_t", JE.string "subscribe")
        , ("topic", JE.string topic)
        ]
    Call { path, argument } token -> JE.object
        [ ("_t", JE.string "call")
        , ("path", JE.string path)
        , ("argument", argument)
        , ("token", token)
        ]

responseDecoder : Decoder Response
responseDecoder = JD.field "_t" JD.string |> JD.andThen (\t -> case t of
    "got_contract" -> JD.map  GotContract (JD.field "contract" contractDecoder)
    "got_value"    -> JD.map2 GotValue
        (JD.field "path"     JD.string)
        (JD.field "value"    JD.value)
    "call_result"  -> JD.map2 CallResult
        (JD.field "token" JD.value)
        (JD.field "value" JD.value)
    "call_error"   -> JD.map2 CallResult
        (JD.field "token" JD.value)
        (JD.field "error" JD.value)
    "connected"    -> JD.succeed Connected
    "disconnected" -> JD.succeed Disconnected
    unknown        -> JD.succeed <| Unknown <| JE.object
        [ ("error", JE.string "unknown key")
        , ("key",   JE.string unknown)
        ]
    )
