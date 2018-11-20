module Ui.Action exposing (Action(..), ActionResult(..))

import Contracts exposing (Callee)
import Json.Encode as JE

type Action
    = RequestCall Callee JE.Value String

type ActionResult
    = CallResult JE.Value String
