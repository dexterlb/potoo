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
      string "get_contract", 
      object [("pid", int n)],
      object [("msg", string "got_contract"), ("pid", int n)]
    ]
  ))

parseResponse : String -> Result String Response
parseResponse s = JD.decodeString responseDecoder s

responseDecoder : Decoder Response
responseDecoder = JD.index 1 tokenDecoder
  |> JD.andThen (responseByTokenDecoder >> JD.index 0)

responseByTokenDecoder : Token -> Decoder Response
responseByTokenDecoder (GotContractToken pid)
  = JD.map (GotContract pid) contractDecoder

tokenDecoder : Decoder Token
tokenDecoder = JD.field "msg" JD.string
  |> JD.andThen (\m -> case m of
    "got_contract" -> JD.map GotContractToken <| JD.field "pid" JD.int
    other -> JD.fail <| "unknown token: " ++ other
  )

type Token
  = GotContractToken Int

type Response
  = GotContract Int Contract