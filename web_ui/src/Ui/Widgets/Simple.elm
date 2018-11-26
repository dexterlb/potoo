module Ui.Widgets.Simple exposing (..)

import Ui.MetaData exposing (MetaData, noMetaData)
import Html exposing (Html, div, text, Attribute)
import Html.Attributes exposing (class)

type alias Attributes msg = List (Attribute msg)

renderHeaderExtra : Attributes msg -> MetaData -> List (Html msg) -> List (Html msg) -> Html msg
renderHeaderExtra attrs meta body extra =
    div (metaAttributes meta ++ attrs) ([
        div [ class "header" ] [ text <| label meta],
        div [ class "body"   ] body
    ] ++ extra)

metaAttributes : MetaData -> Attributes msg
metaAttributes { key, description, uiLevel } =
    let
        level = case uiLevel of
            0 -> "basic"
            1 -> "average"
            _ -> "advanced"
    in
        [ class "widget", class ("level-" ++ level) ]

label : MetaData -> String
label { key, description } = case description of
    ""   -> key
    _    -> description

renderHeader : Attributes msg -> MetaData -> List (Html msg) -> Html msg
renderHeader attrs m body = renderHeaderExtra attrs m body []

renderHeaderWithChildren : Attributes msg -> MetaData -> List (Html msg) -> List (Html msg) -> Html msg
renderHeaderWithChildren attrs m children body = renderHeaderExtra attrs m body
    [ renderChildren children ]

renderChildren : List (Html msg) -> Html msg
renderChildren children = div [ class "children" ] (childify children)

childify : List (Html msg) -> List (Html msg)
childify children =
    List.map (\child -> div [ class "child" ] [ child ]) children

renderStringWidget : MetaData -> String -> List (Html msg) -> Html msg
renderStringWidget m v children = renderHeaderWithChildren [ class "string-value" ] m children <|
    [ text v ]

renderNumberWidget : MetaData -> Float -> List (Html msg) -> Html msg
renderNumberWidget m v children = renderHeaderWithChildren [ class "number-value" ] m children <|
    [ text (String.fromFloat v) ]

renderBoolWidget : MetaData -> Bool -> List (Html msg) -> Html msg
renderBoolWidget m b children = renderHeaderWithChildren [ class "bool-value" ] m children <|
    [ text (case b of
        True  -> "\u{2714}"
        False -> "\u{274c}"
    ) ]

renderListWidget   : MetaData -> List (Html msg) -> Html msg
renderListWidget m children = renderHeader [ class "list" ] m <| childify children

renderDelegateWidget : MetaData -> Int -> List (Html msg) -> Html msg
renderDelegateWidget m _ children = renderHeader [ class "connected-delegate" ] m <|
    (childify children)

renderBrokenWidget : MetaData -> Int -> Html msg
renderBrokenWidget m _ = renderHeader [ class "broken-delegate" ] m <|
    [ text "not connected" ]

renderUnknownWidget : List (Html msg) -> Html msg
renderUnknownWidget children = renderHeader
    [ class "unknown-widget" ]
    { noMetaData | key = "unknown_widget" } <|
        (childify children)
