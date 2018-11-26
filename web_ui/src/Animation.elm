port module Animation exposing (times)

import Json.Encode as JE
import Json.Decode as JD

port rawTimes   : (JE.Value -> msg) -> Sub msg

times : (Float -> msg) -> Sub msg
times f = rawTimes (f << \v -> case JD.decodeValue JD.float v of
    Ok t    -> t
    Err _   -> -1)
