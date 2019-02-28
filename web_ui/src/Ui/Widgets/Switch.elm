module Ui.Widgets.Switch exposing (Model, Msg, init, update, updateMetaData, updateValue, view)

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
    , transitioning: Bool
    }


type Msg
    = Toggle


init : MetaData -> Value -> Model
init meta v =
    { metaData = meta
    , value = getValue v
    , transitioning = False
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case (msg, model.value) of
    (Toggle, Just b) ->
        let v = JE.bool (not b) in
            ( { model | transitioning = True },
              Cmd.none, [ RequestSet model.metaData.propData.property v ] )
    (Toggle, Nothing) ->
        (model, Cmd.none, [])


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = getValue v, transitioning = updateTransitioning model.transitioning model.value (getValue v) }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "switch" ] m.metaData children <|
        [ div ([ class "checkbox" ] ++ action lift m ++ transitioningClass m ++ valueClass m)
            [ ]
        ]

getValue : Value -> Maybe Bool
getValue v = case v of
    SimpleBool b -> Just b
    _            -> Nothing

updateTransitioning : Bool -> Maybe Bool -> Maybe Bool -> Bool
updateTransitioning trans old new = case (trans, old, new) of
    (True, Just o, Just n) -> o /= n
    (_, _, _)              -> False

transitioningClass : Model -> List (Attribute msg)
transitioningClass { transitioning } = case transitioning of
    True  -> [ class "transitioning" ]
    False -> []

valueClass : Model -> List (Attribute msg)
valueClass { value } = case value of
    Just True  -> [ class "on" ]
    Just False -> [ class "off" ]
    Nothing    -> [ class "unknown" ]


action : (Msg -> msg) -> Model -> List (Attribute msg)
action lift m = case m.metaData.propData.hasSetter of
    False -> []
    True  -> [ onClick (lift Toggle) ]
