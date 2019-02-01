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
import Maybe exposing (withDefault)
import Round exposing (round)

type alias Model =
    { metaData:     MetaData
    , value:        Maybe Float
    , userValue:    Float
    , lastUpdate:   Float
    , dirty:        Bool
    , displayRatio: Float
    }


type Msg
    = Set Float


init : MetaData -> Value -> Model
init meta v =
    { metaData      = meta
    , value         = getValue v
    , userValue     = -1
    , lastUpdate    = -42
    , dirty         = False
    , displayRatio  = withDefault 0   meta.valueMeta.min
    }

getMin          { metaData } = withDefault 0   metaData.valueMeta.min
getMax          { metaData } = withDefault 1   metaData.valueMeta.max
getStep         { metaData } = withDefault 0.1 metaData.valueMeta.step
getSpeed        { metaData } = withDefault 2   metaData.valueMeta.speed
getExpSpeed     { metaData } = withDefault 0.2 metaData.valueMeta.expSpeed
getDecimals     { metaData } = withDefault 5   metaData.valueMeta.decimals

getStop : Model -> Float -> Maybe String
getStop { metaData } v = findStop v metaData.valueMeta.stops

findStop : Float -> List (Float, String) -> Maybe String
findStop v l = case l of
    [] -> Nothing
    (stop, name)::rest -> case v >= stop of
        True  -> Just name
        False -> findStop v rest

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
            ratio = (v - getMin model) / (getMax model - getMin model)
        in
            { model | displayRatio = animateValue (getSpeed model) (getExpSpeed model) diff ratio model.displayRatio }
    Nothing -> model

getValue : Value -> Maybe Float
getValue v = case v of
    SimpleFloat f -> Just f
    _             -> Nothing

calcRatio : Model -> Float -> Float
calcRatio m f = (f - (getMin m)) / ((getMax m) - (getMin m))

calcPercent : Model -> Float -> Float
calcPercent m f = (calcRatio m f) * 100

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "slider", stopClass m ] m.metaData children <|
        case m.value of
            Nothing -> [ div [ class "loading" ] [] ]
            Just v  -> let percent = m.displayRatio * 100 in
                [ div [ class "value" ] [ text (round (getDecimals m) v) ]
                , div [ class "outer" ] (renderStopRects m)
                ] ++ (case m.metaData.propData.hasSetter of
                    False -> []
                    True  ->
                        [ input
                            [ Attrs.type_ "range"
                            , Attrs.min  (getMin  m |> String.fromFloat)
                            , Attrs.max  (getMax  m |> String.fromFloat)
                            , Attrs.step (getStep m |> String.fromFloat)
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

renderStopRects : Model -> List (Html msg)
renderStopRects m
    = (List.reverse ((getMax m, "foo") :: m.metaData.valueMeta.stops))
    |> List.map2 (\(v1, n1) (v2, _) -> (v1, v2, n1)) ((getMin m, "nostop")::(List.reverse m.metaData.valueMeta.stops))
    |> List.map (\(left, right, name) ->
        let
            leftRatio  = calcRatio m left
            rightRatio = calcRatio m right
        in let
            innerRatio = clamp 0 1 <| (m.displayRatio - leftRatio) / (rightRatio - leftRatio)
        in let
            leftPercent  = leftRatio  * 100
            rightPercent = rightRatio * 100
            innerPercent = innerRatio * 100
        in
            div [ if m.displayRatio * 100 < leftPercent then
                    class "below"
                  else if m.displayRatio * 100 >= rightPercent then
                    class "above"
                  else
                    class "inside"
                , class ("stoprec-" ++ name)
                , class "stoprec"
                , style "width" (String.fromFloat (rightPercent - leftPercent) ++ "%")
                , style "left"  (String.fromFloat                 leftPercent  ++ "%")
                ]
                [ div [ class "inner", style "width" (String.fromFloat innerPercent ++ "%") ] []
                ]
        )

stopClass : Model -> Attribute msg
stopClass m = case m.value |> Maybe.andThen (\_ -> getStop m (getMin m + (getMax m - getMin m) * m.displayRatio)) of
    Just name -> class ("stop-" ++ name)
    Nothing   -> class ("stop-nostop")

animateValue : Float -> Float -> Float -> Float -> Float -> Float
animateValue speed expSpeed diff new old = let delta = speed * diff + expSpeed * (abs (new - old)) in
    case new > old of
        True  -> min new (old + delta)
        False -> max new (old - delta)
