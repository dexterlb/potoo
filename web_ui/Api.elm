module Api exposing (..)

import WebSocket
import Json.Encode exposing (encode, string, object, int, list)
import Json.Decode as JD exposing (Decoder)

import Contracts exposing (..)

type alias Conn = String

connect : String -> Conn
connect url = url

listenRaw : Conn -> (String -> msg) -> Sub msg
listenRaw conn f = Sub.batch
  [ WebSocket.listen conn f
  , WebSocket.keepAlive conn
  ]

sendRaw : Conn -> String -> Cmd msg
sendRaw conn = WebSocket.send conn

sendPing : Conn -> Cmd msg
sendPing conn = sendRaw conn (encode 4
    (string "ping")
  )

getContract : Conn -> DelegateStruct -> Cmd msg
getContract conn target =
  sendRaw conn (encode 4 (
    list [
      string "get_and_subscribe_contract",
      object [
        ("target", delegateEncoder target),
        ("token", object [("msg", string "got_contract"), ("target", delegateEncoder target)])
      ],
      object [("msg", string "got_contract"), ("pid", int target.destination)]
    ]
  ))

unsafeCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> String -> Cmd msg
unsafeCall conn func tokenString =
  rawUnsafeCall conn func <|
      object [("msg", string "unsafe_call_result"), ("token_string", string tokenString)]

getterCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
getterCall conn func (propertyPid, propertyID) =
  rawUnsafeCall conn func <|
    object [
        ("msg", string "property_value"),
        ("pid", int propertyPid),
        ("id",  int propertyID)
      ]

setterCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
setterCall conn func (propertyPid, propertyID) =
  rawUnsafeCall conn func <|
    object [
        ("msg", string "property_setter_status"),
        ("pid", int propertyPid),
        ("id",  int propertyID)
      ]

actionCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> Cmd msg
actionCall conn func =
  rawUnsafeCall conn func <|
    object [
        ("msg", string "action_result")
      ]

subscriberCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
subscriberCall conn func (propertyPid, propertyID) =
  rawUnsafeCall conn func <|
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

subscribe : Conn -> Channel -> Json.Encode.Value -> Cmd msg
subscribe conn chan token =
  sendRaw conn (encode 4 (
    list [
      string "subscribe",
      object [
        ("channel", channelEncoder chan),
        ("token", token)
      ],
      object [("msg", string "subscribed_channel"), ("token", token)]
    ]
  ))


rawUnsafeCall : Conn -> { target: DelegateStruct, name: String, argument: Json.Encode.Value } -> Json.Encode.Value -> Cmd msg
rawUnsafeCall conn {target, name, argument} token =
  sendRaw conn (encode 4 (
    list [
      string "unsafe_call",
      object [
          ("target", delegateEncoder target),
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
  [ pongDecoder
  , helloDecoder
  , JD.index 1 tokenDecoder
      |> JD.andThen (responseByTokenDecoder >> JD.index 0)
  ]

pongDecoder : Decoder Response
pongDecoder = JD.string
  |> JD.andThen (\s -> case s of
    "pong" -> JD.succeed Pong
    _ -> JD.fail "not a pong message"
  )

helloDecoder : Decoder Response
helloDecoder = JD.string
  |> JD.andThen (\s -> case s of
    "hello" -> JD.succeed Hello
    _ -> JD.fail "not a hello message"
  )

responseByTokenDecoder : Token -> Decoder Response
responseByTokenDecoder t = case t of
  GotContractToken pid -> JD.map (GotContract pid) contractDecoder
  ValueResultToken pid_id -> JD.map (ValueResult pid_id) JD.value
  PropertySetterStatusToken pid_id -> JD.map (PropertySetterStatus pid_id) JD.value
  ChannelResultToken token -> JD.map (ChannelResult token) channelDecoder
  SubscribedChannelToken token -> JD.succeed <| SubscribedChannel token
  UnsafeCallResultToken tokenString -> JD.map (UnsafeCallResult tokenString) JD.value

tokenDecoder : Decoder Token
tokenDecoder = JD.field "msg" JD.string
  |> JD.andThen (\m -> case m of
    "got_contract" -> JD.map GotContractToken <| JD.field "pid" JD.int
    "unsafe_call_result" -> JD.map UnsafeCallResultToken <| JD.field "token_string" JD.string
    "channel_result" -> JD.map ChannelResultToken <| JD.field "token" JD.value
    "subscribed_channel" -> JD.map SubscribedChannelToken <| JD.field "token" JD.value
    "property_setter_status" -> JD.map2 (\pid id -> PropertySetterStatusToken (pid, id))
      (JD.field "pid" JD.int)
      (JD.field "id" JD.int)
    "property_value" -> JD.map2 (\pid id -> ValueResultToken (pid, id))
      (JD.field "pid" JD.int)
      (JD.field "id" JD.int)
    other -> JD.fail <| "unknown token: " ++ other
  )

type Token
  = GotContractToken Int
  | ValueResultToken (Int, Int)
  | UnsafeCallResultToken String
  | ChannelResultToken Json.Encode.Value
  | SubscribedChannelToken Json.Encode.Value
  | PropertySetterStatusToken (Int, Int)

type Response
  = GotContract Int Contract
  | ValueResult (Int, Int) Json.Encode.Value
  | UnsafeCallResult String Json.Encode.Value
  | ChannelResult Json.Encode.Value Channel
  | SubscribedChannel Json.Encode.Value
  | PropertySetterStatus (Int, Int) Json.Encode.Value
  | Pong
  | Hello
