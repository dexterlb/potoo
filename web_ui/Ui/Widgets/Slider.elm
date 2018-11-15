module Ui.Widgets.Slider exposing (..)

import Ui.Action    exposing (..)
import Ui.MetaData  exposing (..)
import Contracts    exposing (Value)

type Model = NoModel

type Msg   = NoMsg

init : MetaData -> { min: Float, max: Float } -> Model
init _ _ = NoModel

update : Msg -> Model -> (Model, Cmd Msg, List Action)
update NoMsg NoModel = (NoModel, Cmd.none, [])

updateValue : Value -> Model -> (Model, Cmd Msg, List Action)
updateValue _ _ = (NoModel, Cmd.none, [])

updateMetaData : MetaData -> Model -> (Model, Cmd Msg, List Action)
updateMetaData _ _ = (NoModel, Cmd.none, [])
