module Ui.Widgets.Switch exposing (Model, Msg, init, update, updateMetaData, updateValue, view, animate)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value(..), inspectType, typeErrorToString, TypeError(..), typeCheck)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text, button, input, Attribute)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Json.Decode as JD

import Random
import Random.Char
import Random.String

type alias Model =
    { metaData:      MetaData
    , value:         Maybe Bool
    , dirty:         Bool
    , waiting:       Bool
    , lastUpdate:    Float
    }


type Msg
    = Toggle


init : MetaData -> Value -> Model
init meta v =
    { metaData = meta
    , value = getValue v
    , dirty = False
    , waiting = False
    , lastUpdate = -42
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case (msg, model.value) of
    (Toggle, Just b) ->
        let v = JE.bool (not b) in
            ( { model | dirty = True },
              Cmd.none, case model.metaData.property of
                  Just prop -> [ RequestSet prop v ]
                  Nothing   -> [])
    (Toggle, Nothing) ->
        (model, Cmd.none, [])


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = getValue v, waiting = False }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "switch" ] m.metaData children <|
        [ div ([ class "checkbox" ] ++ action lift m ++ waitingClass m ++ valueClass m)
            [ ]
        ]

getValue : Value -> Maybe Bool
getValue v = case v of
    SimpleBool b -> Just b
    _            -> Nothing

waitingClass : Model -> List (Attribute msg)
waitingClass { waiting } = case waiting of
    True  -> [ class "waiting" ]
    False -> []

valueClass : Model -> List (Attribute msg)
valueClass { value } = case value of
    Just True  -> [ class "on" ]
    Just False -> [ class "off" ]
    Nothing    -> [ class "unknown" ]


action : (Msg -> msg) -> Model -> List (Attribute msg)
action lift m = case hasSetter m.metaData of
    False -> []
    True  -> [ onClick (lift Toggle) ]

animate : (Float, Float) -> Model -> Model
animate t = animateLastUpdate t >> animateWaiting t

animateLastUpdate : (Float, Float) -> Model -> Model
animateLastUpdate (time, _) model = case model.dirty of
    True  -> { model | lastUpdate = time, dirty = False, waiting = True }
    False -> model

animateWaiting : (Float, Float) -> Model -> Model
animateWaiting (time, _) model = case model.waiting of
    True -> case time < model.lastUpdate + 2 of
        True  -> model
        False -> { model | waiting = False }
    False -> model
