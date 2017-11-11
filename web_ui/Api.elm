module Api exposing (..)

import WebSocket
import Json.Encode exposing (encode, string, object, int, list)

import Contracts exposing (..)

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