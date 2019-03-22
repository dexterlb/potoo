module Ui.Widgets.Slider exposing (Model, Msg(..), init, update, updateMetaData, updateValue, view, animate)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren, renderNumberValue)

import Contracts exposing (Value(..))
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)


import Html exposing (Html, div, text, button, input, span, Attribute)
import Html.Attributes exposing (class, style)
import Html.Attributes as Attrs
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Maybe exposing (withDefault)

type alias Model =
    { metaData:     MetaData
    , value:        Maybe Float
    , userValue:    Float
    , lastUpdate:   Float
    , dirty:        Bool
    , displayRatio: Float
    , peakRatio:    Float
    , lastPeakTime: Float
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
    , peakRatio     = 0
    , lastPeakTime  = -42
    }

getMin          { metaData } = withDefault 0   metaData.valueMeta.min
getMax          { metaData } = withDefault 1   metaData.valueMeta.max
getUnits        { metaData } = getStringTag "units" metaData.uiTags
getStep         { metaData } = withDefault 0.1 <| getFloatTag "step"      metaData.uiTags
getSpeed        { metaData } = withDefault 2   <| getFloatTag "speed"     metaData.uiTags
getExpSpeed     { metaData } = withDefault 0.2 <| getFloatTag "exp_speed" metaData.uiTags
getDecimals     { metaData } = withDefault 5   <| getIntTag   "decimals"  metaData.uiTags
getGrid         { metaData } =                    getFloatTag "grid"  metaData.uiTags

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
        ( { model | userValue = f, dirty = True }, Cmd.none, case model.metaData.property of
            Just prop -> [ RequestSet prop (JE.float f) ]
            Nothing   -> [])


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = getValue v }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

animate : (Float, Float) -> Model -> Model
animate t = animateLastUpdate t >> animateRatio t >> animateUserValue t >> animatePeak t

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
            { model | displayRatio = clamp 0 1 <| animateValue (getSpeed model) (getExpSpeed model) diff ratio model.displayRatio }
    Nothing -> model

animatePeak : (Float, Float) -> Model -> Model
animatePeak (time, diff) model = case model.displayRatio > model.peakRatio of
    True  -> { model | peakRatio = model.displayRatio, lastPeakTime = time }
    False -> case model.lastPeakTime + 2.0 < time of
        False  -> model
        True   -> { model | peakRatio = animateValue 0.05 0 diff model.displayRatio model.peakRatio }

getValue : Value -> Maybe Float
getValue v = case v of
    SimpleFloat f -> Just f
    _             -> Nothing

calcRatio : Model -> Float -> Float
calcRatio m f = (f - (getMin m)) / ((getMax m) - (getMin m))

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "slider", stopClass m ] m.metaData children <|
        case m.value of
            Nothing -> [ div [ class "loading" ] [] ]
            Just v  ->
                [ renderNumberValue m.metaData v
                , div [ class "outer" ] ((renderStopRects m) ++ renderGrid m)
                ] ++ (case hasSetter m.metaData of
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
            peakRatio  = clamp 0 1 <| (m.peakRatio    - leftRatio) / (rightRatio - leftRatio)
        in
            div [ if m.displayRatio < leftRatio then
                    class "below"
                  else if m.displayRatio >= rightRatio then
                    class "above"
                  else
                    class "inside"
                , if m.peakRatio <= leftRatio then
                    class "peak-below"
                  else if m.peakRatio > rightRatio then
                    class "peak-above"
                  else
                    class "peak-inside"
                , class ("stoprec-" ++ name)
                , class "stoprec"
                , percentWidth <| rightRatio - leftRatio
                , percentStyle "left" leftRatio
                ]
                [ div [ class "inner", percentWidth innerRatio ] []
                , div [ class "peak",  percentWidth peakRatio  ] []
                , div [ class "stop-value-left"  ] [ renderNumberValue m.metaData left ]
                , div [ class "stop-value-right" ] [ renderNumberValue m.metaData right ]
                , div [ class "stop-info" ] []
                ]
        )

renderGrid : Model -> List (Html msg)
renderGrid m = case getGrid m of
    Nothing   -> []
    Just grid ->
        [ div [ class "grid" ] <| List.map (renderGridRect m) <| linspace grid (getMin m) (getMax m) ]

renderGridRect : Model -> Float -> Html msg
renderGridRect m v = div
    [ class "grid-rect", percentWidth (v / (getMax m - getMin m)) ]
    [ ]

linspace : Float -> Float -> Float -> List Float
linspace delta start end = linspaceN (floor <| (end - start) / delta) start end

linspaceN : Int -> Float -> Float -> List Float
linspaceN n start end = List.map (\i -> i * ((end - start) / (toFloat n - 1))) <| List.map toFloat <| List.range 1 (n-1)

percentWidth : Float -> Attribute msg
percentWidth = percentStyle "width"

percentStyle : String -> Float -> Attribute msg
percentStyle name ratio = style name <| String.fromFloat (ratio * 100) ++ "%"

stopClass : Model -> Attribute msg
stopClass m = case m.value |> Maybe.andThen (\_ -> getStop m (getMin m + (getMax m - getMin m) * m.displayRatio)) of
    Just name -> class ("stop-" ++ name)
    Nothing   -> class ("stop-nostop")

animateValue : Float -> Float -> Float -> Float -> Float -> Float
animateValue speed expSpeed diff new old = let delta = speed * diff + expSpeed * (abs (new - old)) in
    case new > old of
        True  -> min new (old + delta)
        False -> max new (old - delta)
