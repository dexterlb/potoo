module Ui.Widgets.Slider exposing (Model, Msg(..), init, update, updateMetaData, updateValue, view)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Contracts exposing (Value(..))
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)


import Html exposing (Html, div, text, button, input, Attribute)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick, onInput)

type alias Model =
    { metaData: MetaData
    , value:    Maybe Float
    , min:      Float
    , max:      Float
    , step:     Float
    }


type Msg
    = NoMsg


init : MetaData -> Value -> { min : Float, max : Float, step : Float } -> Model
init meta v { min, max, step } =
    { metaData  = meta
    , value     = getValue v
    , min       = min
    , max       = max
    , step      = step
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

getValue : Value -> Maybe Float
getValue v = case v of
    SimpleFloat f -> Just f
    _             -> Nothing

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "slider" ] m.metaData children <|
        case m.value of
            Nothing -> [ div [ class "loading" ] [] ]
            Just v  -> let percent = ((v - m.min) / (m.max - m.min)) * 100 in
                [ div [ class "value" ] [ text (String.fromFloat v) ]
                , div [ class "outer" ]
                    [ div [ class "inner", style "width" (String.fromFloat percent ++ "%") ] []
                    ]
                ]

