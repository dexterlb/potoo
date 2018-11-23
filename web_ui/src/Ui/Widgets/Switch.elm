module Ui.Widgets.Switch exposing (Model, Msg, init, update, updateMetaData, updateValue, view)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value(..), inspectType, typeErrorToString, TypeError(..), typeCheck)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text, button, input)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Json.Decode as JD

import Random
import Random.Char
import Random.String

type alias Model =
    { metaData: MetaData
    , value:    Maybe Bool
    }


type Msg
    = NoMsg


init : MetaData -> Value -> Model
init meta v =
    { metaData = meta
    , value = getValue v
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update NoMsg model =
    ( model, Cmd.none, [] )


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = getValue v }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "switch" ] m.metaData children <|
        [ text (case m.value of
            Just True  -> "\u{2714}"
            Just False -> "\u{274c}"
            Nothing    -> "?"
        ) ]

getValue : Value -> Maybe Bool
getValue v = case v of
    SimpleBool b -> Just b
    _            -> Nothing
