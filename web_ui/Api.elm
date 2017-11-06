module Api exposing (..)

import WebSocket
import Dict exposing (Dict)
import Json.Encode exposing (encode, string, object, int, list)

type alias Data = Dict String String

type Type
  = TInt Int
  | TFloat Float

type Contract
  = StringValue String
  | Delegate {
    destination : Int,
    data: Data
  }
  | Function {
    argument: Type,
    name: String,
    retval: Type,
    data: Data
  }
  | MapContract (Dict String Contract)
  | ListContract (List Contract)

ws : String
ws = "ws://localhost:4040/ws"

listenRaw : (String -> msg) -> Sub msg
listenRaw = WebSocket.listen ws

sendRaw : String -> Cmd msg
sendRaw = WebSocket.send ws

getContract : Cmd msg
getContract =
  sendRaw (encode 4 (
    list [
      string "get_contract", 
      object [("pid", int 0)],
      int 42
    ]
  ))