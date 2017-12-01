module Api exposing (..)

import WebSocket
import Json.Encode exposing (encode, string, object, int, list)
import Json.Decode as JD exposing (Decoder)

import Contracts exposing (..)

ws : String
ws = "ws://localhost:4040/ws"

listenRaw : (String -> msg) -> Sub msg
listenRaw = WebSocket.listen ws

sendRaw : String -> Cmd msg
sendRaw = WebSocket.send ws

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
unsafeCall data tokenString =
  rawUnsafeCall data <|
      object [("msg", string "unsafe_call_result"), ("token_string", string tokenString)]

getterCall : { pid: Int, name: String, argument: Json.Encode.Value } -> (Int, Int) -> Cmd msg
getterCall data (propertyPid, propertyID) =
  rawUnsafeCall data <|
      object [
          ("msg", string "getter_call_result"),
          ("pid", int propertyPid),
          ("id",  int propertyID)
        ]


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
responseDecoder = JD.index 1 tokenDecoder
  |> JD.andThen (responseByTokenDecoder >> JD.index 0)

responseByTokenDecoder : Token -> Decoder Response
responseByTokenDecoder t = case t of
  GotContractToken pid -> JD.map (GotContract pid) contractDecoder
  GetterCallResultToken pid_id -> JD.map (GetterCallResult pid_id) JD.value
  UnsafeCallResultToken tokenString -> JD.map (UnsafeCallResult tokenString) JD.value

tokenDecoder : Decoder Token
tokenDecoder = JD.field "msg" JD.string
  |> JD.andThen (\m -> case m of
    "got_contract" -> JD.map GotContractToken <| JD.field "pid" JD.int
    "unsafe_call_result" -> JD.map UnsafeCallResultToken <| JD.field "token_string" JD.string
    "getter_call_result" -> JD.map2 (\pid id -> GetterCallResultToken (pid, id))
      (JD.field "pid" JD.int)
      (JD.field "id" JD.int)
    other -> JD.fail <| "unknown token: " ++ other
  )

type Token
  = GotContractToken Int
  | GetterCallResultToken (Int, Int)
  | UnsafeCallResultToken String

type Response
  = GotContract Int Contract
  | GetterCallResult (Int, Int) Json.Encode.Value
  | UnsafeCallResult String Json.Encode.Value