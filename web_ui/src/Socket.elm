port module Socket exposing (outgoing, incoming)

import Json.Encode as JE

port outgoing   : JE.Value -> Cmd msg
port incoming   : (JE.Value -> msg) -> Sub msg
