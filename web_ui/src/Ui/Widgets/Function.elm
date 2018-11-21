module Ui.Widgets.Function exposing (Model, Msg, init, update, updateMetaData, view, pushResult)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value, inspectType)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)

import Json.Encode as JE


type alias Model =
    { metaData        : MetaData
    , callee          :   Callee
    , currentArgument : Maybe JE.Value
    , token           : Maybe String
    }


type Msg
    = NoMsg


init : MetaData -> Callee -> Model
init meta c =
    { metaData = meta
    , callee = c
    , currentArgument = Nothing
    , token = Nothing
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update NoMsg model =
    ( model, Cmd.none, [] )

pushResult : ActionResult -> Model -> ( Model, Cmd Msg, List Action )
pushResult _ model = ( model, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift { metaData, callee } children =
    renderHeaderWithChildren [ class "function" ] metaData children <|
    [ div [ class "function-type" ]
        [ div [ class "argument" ] [ text <| inspectType callee.argument ]
        , div [ class "retval"   ] [ text <| inspectType callee.retval   ]
        ]
    , div [ class "function-callbox" ]
        [
        ]
    ]
