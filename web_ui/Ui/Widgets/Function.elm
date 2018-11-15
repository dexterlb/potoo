module Ui.Widgets.Function exposing (..)

import Ui.Action    exposing (..)
import Ui.MetaData  exposing (..)
import Contracts    exposing (Value, Callee)

type Model = NoModel

type Msg   = NoMsg

init : Callee -> Model
init _ = NoModel

update : Msg -> Model -> (Model, Cmd Msg, List Action)
update NoMsg NoModel = (NoModel, Cmd.none, [])

updateMetaData : MetaData -> Model -> (Model, Cmd Msg, List Action)
updateMetaData _ _ = (NoModel, Cmd.none, [])
