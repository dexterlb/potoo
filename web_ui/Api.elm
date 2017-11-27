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
unsafeCall {pid, name, argument} tokenString =
  sendRaw (encode 4 (
    list [
      string "unsafe_call",
      object [
          ("pid", int pid),
          ("function_name", string name),
          ("argument", argument)
        ],
      object [("msg", string "unsafe_call_result"), ("token_string", string tokenString)]
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
  UnsafeCallResultToken tokenString -> JD.map (UnsafeCallResult tokenString) JD.value

tokenDecoder : Decoder Token
tokenDecoder = JD.field "msg" JD.string
  |> JD.andThen (\m -> case m of
    "got_contract" -> JD.map GotContractToken <| JD.field "pid" JD.int
    "unsafe_call_result" -> JD.map UnsafeCallResultToken <| JD.field "token_string" JD.string
    other -> JD.fail <| "unknown token: " ++ other
  )

type Token
  = GotContractToken Int
  | UnsafeCallResultToken String

type Response
  = GotContract Int Contract
  | UnsafeCallResult String Json.Encode.Value