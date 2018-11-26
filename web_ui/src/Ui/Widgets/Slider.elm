module Ui.Widgets.Slider exposing (Model, Msg(..), init, update, updateMetaData, updateValue, view, animate)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Contracts exposing (Value(..))
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)


import Html exposing (Html, div, text, button, input, Attribute)
import Html.Attributes exposing (class, style)
import Html.Attributes as Attrs
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE

type alias Model =
    { metaData:     MetaData
    , value:        Maybe Float
    , userValue:    Float
    , lastUpdate:   Float
    , dirty:        Bool
    , displayRatio: Float
    , min:          Float
    , max:          Float
    , step:         Float
    , speed:        Float
    }


type Msg
    = Set Float


init : MetaData -> Value -> { min : Float, max : Float, step : Float, speed : Float } -> Model
init meta v { min, max, step, speed } =
    { metaData      = meta
    , value         = getValue v
    , userValue     = -1
    , lastUpdate    = 0
    , dirty         = True
    , min           = min
    , max           = max
    , step          = step
    , speed         = speed
    , displayRatio  = min
    }

update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case msg of
    Set f ->
        ( { model | userValue = f, dirty = True }, Cmd.none, [ RequestSet model.metaData.propData.property (JE.float f) ])


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = getValue v }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

animate : (Float, Float) -> Model -> Model
animate t = animateLastUpdate t >> animateRatio t >> animateUserValue t

animateLastUpdate : (Float, Float) -> Model -> Model
animateLastUpdate (time, _) model = case model.dirty of
    True  -> { model | lastUpdate = time, dirty = False }
    False -> model

animateUserValue : (Float, Float) -> Model -> Model
animateUserValue (time, _) model = case model.value of
    Just v -> case time < model.lastUpdate + 2 of
        True  -> model
        False -> { model | userValue = v }
    Nothing -> model

animateRatio : (Float, Float) -> Model -> Model
animateRatio (_, diff) model = case model.value of
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
                ] ++ (case m.metaData.propData.hasSetter of
                    False -> []
                    True  ->
                        [ input
                            [ Attrs.type_ "range"
                            , Attrs.min  (m.min  |> String.fromFloat)
                            , Attrs.max  (m.max  |> String.fromFloat)
                            , Attrs.step (m.step |> String.fromFloat)
                            , Attrs.value <| String.fromFloat m.userValue
                            , onInput
                                (\s ->
                                    s
                                        |> String.toFloat
                                        |> Maybe.withDefault -1
                                        |> lift << Set
                                )
                            ] []
                        ]
                )

animateValue : Float -> Float -> Float -> Float -> Float
animateValue speed diff new old = let delta = speed * diff + 0.2 * (abs (new - old)) in
    case new > old of
        True  -> min new (old + delta)
        False -> max new (old - delta)
