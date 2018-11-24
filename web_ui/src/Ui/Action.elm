module Ui.Action exposing (Action(..), ActionResult(..))

import Contracts exposing (Callee, Pid, PropertyID)
import Json.Encode as JE

type Action
    = RequestCall Callee JE.Value String
    | RequestSet  (Pid, PropertyID) JE.Value
    | RequestGet  (Pid, PropertyID) JE.Value

type ActionResult
    = CallResult JE.Value String
