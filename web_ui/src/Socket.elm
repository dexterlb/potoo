port module Socket exposing (Socket)

import Json.Encode as JE

port outgoing   : JE.Value -> Cmd msg
port incoming   : (JE.Value -> msg) -> Sub msg
