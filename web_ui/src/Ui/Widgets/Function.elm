module Ui.Widgets.Function exposing (Model, Msg, init, update, updateMetaData, view)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


type alias Model =
    { metaData: MetaData
    , callee:   Callee
    }


type Msg
    = NoMsg


init : MetaData -> Callee -> Model
init meta c = { metaData = meta, callee = c }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update NoMsg model =
    ( model, Cmd.none, [] )


updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift { metaData } children =
    renderHeaderWithChildren [ class "function" ] metaData children <|
    [ text "func2" ]
