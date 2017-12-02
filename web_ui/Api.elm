module Api exposing (..)

import WebSocket
import Json.Encode exposing (encode, string, object, int, list)
import Json.Decode as JD exposing (Decoder)

import Contracts exposing (..)

ws : String
ws = "ws://localhost:4040/ws"

listenRaw : (String -> msg) -> Sub msg
listenRaw f = Sub.batch
  [ WebSocket.listen ws f
  , WebSocket.keepAlive ws
  ]

sendRaw : String -> Cmd msg
sendRaw = WebSocket.send ws

sendPing : Cmd msg
sendPing = sendRaw (encode 4
    (string "ping")
  )

getContract : Int -> Cmd msg
getContract n =
  sendRaw (encode 4 (
    list [
      string "get_and_subscribe_contract", 
      object [
        ("pid", int n),
        ("token", object [("msg", string "got_contract"), ("pid", int n)])
      ],
      object [("msg", string "got_contract"), ("pid", int n)]
    ]
  ))

unsafeCall : { pid: Int, name: String, argument: Json.Encode.Value } -> String -> Cmd msg
unsafeCall func tokenString =
  rawUnsafeCall func <|
      object [("msg", string "unsafe_call_result"), ("token_string", string tokenString)]

getterCall : { pid: Int, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
getterCall func (propertyPid, propertyID) =
  rawUnsafeCall func <|
    object [
        ("msg", string "property_value"),
        ("pid", int propertyPid),
        ("id",  int propertyID)
      ]

subscriberCall : { pid: Int, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
subscriberCall func (propertyPid, propertyID) =
  rawUnsafeCall func <|
    object [
      ("msg", string "channel_result"),
      ("token",
        object [
            ("msg", string "property_value"),
            ("pid", int propertyPid),
            ("id",  int propertyID)
          ]
      )
    ]

subscribe : Channel -> Json.Encode.Value -> Cmd msg
subscribe chan token =
  sendRaw (encode 4 (
    list [
      string "subscribe", 
      object [
        ("channel", int chan),
        ("token", token)
      ],
      object [("msg", string "subscribed_channel"), ("token", token)]
    ]
  ))


rawUnsafeCall : { pid: Int, name: String, argument: Json.Encode.Value } -> Json.Encode.Value -> Cmd msg
rawUnsafeCall {pid, name, argument} token =
  sendRaw (encode 4 (
    list [
      string "unsafe_call",
      object [
          ("pid", int pid),
          ("function_name", string name),
          ("argument", argument)
        ],
      token
    ]
  ))

parseResponse : String -> Result String Response
parseResponse s = JD.decodeString responseDecoder s

responseDecoder : Decoder Response
responseDecoder = JD.oneOf
  [ pongDecoder,
    JD.index 1 tokenDecoder
      |> JD.andThen (responseByTokenDecoder >> JD.index 0)
  ]

pongDecoder : Decoder Response
pongDecoder = JD.string
  |> JD.andThen (\s -> case s of
    "pong" -> JD.succeed Pong
    _ -> JD.fail "not a pong message"
  )

responseByTokenDecoder : Token -> Decoder Response
responseByTokenDecoder t = case t of
  GotContractToken pid -> JD.map (GotContract pid) contractDecoder
  PropertyValueResultToken pid_id -> JD.map (PropertyValueResult pid_id) JD.value
  ChannelResultToken token -> JD.map (ChannelResult token) channelDecoder
  SubscribedChannelToken token -> JD.succeed <| SubscribedChannel token
  UnsafeCallResultToken tokenString -> JD.map (UnsafeCallResult tokenString) JD.value

tokenDecoder : Decoder Token
tokenDecoder = JD.field "msg" JD.string
  |> JD.andThen (\m -> case m of
    "got_contract" -> JD.map GotContractToken <| JD.field "pid" JD.int
    "unsafe_call_result" -> JD.map UnsafeCallResultToken <| JD.field "token_string" JD.string
    "channel_result" -> JD.map ChannelResultToken <| JD.field "token" JD.value
    "subscribed_channel" -> JD.map ChannelResultToken <| JD.field "token" JD.value
    "property_value" -> JD.map2 (\pid id -> PropertyValueResultToken (pid, id))
      (JD.field "pid" JD.int)
      (JD.field "id" JD.int)
    other -> JD.fail <| "unknown token: " ++ other
  )

type Token
  = GotContractToken Int
  | PropertyValueResultToken (Int, Int)
  | UnsafeCallResultToken String
  | ChannelResultToken Json.Encode.Value
  | SubscribedChannelToken Json.Encode.Value

type Response
  = GotContract Int Contract
  | PropertyValueResult (Int, Int) Json.Encode.Value
  | UnsafeCallResult String Json.Encode.Value
  | ChannelResult Json.Encode.Value Channel
  | SubscribedChannel Json.Encode.Value
  | Pong