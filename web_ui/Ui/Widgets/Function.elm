module Ui.Widgets.Function exposing (..)

import Ui.Action exposing (..)
import Contracts exposing (Callee)

type Model = NoModel

type Msg   = NoMsg

init : Callee -> Model
init _ = NoModel

update : Msg -> Model -> (Model, Cmd Msg, List Action)
update NoMsg NoModel = (NoModel, Cmd.none, [])
