module Ui.Widgets.Slider exposing (..)

import Ui.Action exposing (..)
import Contracts exposing (Callee)

type Model = NoModel

type Msg   = NoMsg

init : { min: Float, max: Float } -> Model
init _ = NoModel

update : Msg -> Model -> (Model, Cmd Msg, List Action)
update NoMsg NoModel = (NoModel, Cmd.none, [])
