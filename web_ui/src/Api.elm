module Api exposing (Request, Response, api, subscriptions)

import Contracts exposing (..)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE
import Socket

type Response
    = GotContract Contract
    | GotValue JE.Value
    | CallResult String JE.Value
    | CallError  String JE.Value
    | Connected
    | Disconnected
    | Unknown JE.Value

type Request
    = Connect { url: String, root: Topic }
    | Subscribe Topic
    | Call { path: Topic, argument: JE.Value } String



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
        , ("token", JE.string token)
        ]

responseDecoder : Decoder Response
responseDecoder = JD.field "_t" JD.string |> JD.andThen (\t -> case t of
    "got_contract" -> JD.map GotContract (JD.field "contract" contractDecoder)
    "got_value"    -> JD.map GotValue    (JD.field "value"    JD.value)
    "call_result"  -> JD.map2 CallResult
        (JD.field "token" JD.string)
        (JD.field "value" JD.value)
    "call_error"   -> JD.map2 CallResult
        (JD.field "token" JD.string)
        (JD.field "error" JD.value)
    "connected"    -> JD.succeed Connected
    "disconnected" -> JD.succeed Disconnected
    unknown        -> JD.succeed <| Unknown <| JE.object
        [ ("error", JE.string "unknown key")
        , ("key",   JE.string unknown)
        ]
    )
