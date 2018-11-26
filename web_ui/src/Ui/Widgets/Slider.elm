module Ui.Widgets.Slider exposing (Model, Msg(..), init, update, updateMetaData, updateValue, view, animate)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Contracts exposing (Value(..))
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)


import Html exposing (Html, div, text, button, input, Attribute)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick, onInput)

type alias Model =
    { metaData:     MetaData
    , value:        Maybe Float
    , displayRatio: Float
    , min:          Float
    , max:          Float
    , step:         Float
    , speed:        Float
    }


type Msg
    = NoMsg


init : MetaData -> Value -> { min : Float, max : Float, step : Float, speed : Float } -> Model
init meta v { min, max, step, speed } =
    { metaData      = meta
    , value         = getValue v
    , min           = min
    , max           = max
    , step          = step
    , speed         = speed
    , displayRatio  = min
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

animate: (Float, Float) -> Model -> Model
animate (_, diff) model = case model.value of
    Just v  ->
        let
            ratio = (v - model.min) / (model.max - model.min)
        in
            { model | displayRatio = animateValue model.speed diff ratio model.displayRatio }
    Nothing -> model

getValue : Value -> Maybe Float
getValue v = case v of
    SimpleFloat f -> Just f
    _             -> Nothing

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "slider" ] m.metaData children <|
        case m.value of
            Nothing -> [ div [ class "loading" ] [] ]
            Just v  -> let percent = m.displayRatio * 100 in
                [ div [ class "value" ] [ text (String.fromFloat v) ]
                , div [ class "outer" ]
                    [ div [ class "inner", style "width" (String.fromFloat percent ++ "%") ] []
                    ]
                ]

animateValue : Float -> Float -> Float -> Float -> Float
animateValue speed diff new old = let delta = speed * diff + 0.2 * (abs (new - old)) in
    case new > old of
        True  -> min new (old + delta)
        False -> max new (old - delta)
