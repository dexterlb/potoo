module Ui.Widgets.Simple exposing (..)

import Ui.MetaData exposing (MetaData, noMetaData)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)

renderHeaderExtra : MetaData -> Html msg -> List (Html msg) -> Html msg
renderHeaderExtra { key, description, uiLevel } body extra =
    let name = case description of
            ""      -> key
            desc    -> desc
    in let
        level = case uiLevel of
            0 -> "basic"
            1 -> "average"
            _ -> "advanced"
    in
        div [ class "widget", class ("level-" ++ level) ] ([
            div [ class "header" ] [ text name ],
            div [ class "body"   ] [ body ]
        ] ++ extra)

renderHeader : MetaData -> Html msg -> Html msg
renderHeader m body = renderHeaderExtra m body []

renderHeaderWithChildren : MetaData -> List (Html msg) -> Html msg -> Html msg
renderHeaderWithChildren m children body = renderHeaderExtra m body [ renderChildBox children ]


renderChildBox : List (Html msg) -> Html msg
renderChildBox children =
    div [ class "children" ] <|
        List.map (\child -> div [ class "child" ] [ child ]) children

renderStringWidget : MetaData -> String -> List (Html msg) -> Html msg
renderStringWidget m v children = renderHeaderWithChildren m children <|
    div [ class "string-value" ] [ text v ]

renderNumberWidget : MetaData -> Float -> List (Html msg) -> Html msg
renderNumberWidget m v children = renderHeaderWithChildren m children <|
    div [ class "number-value" ] [ text (String.fromFloat v) ]

renderBoolWidget : MetaData -> Bool -> List (Html msg) -> Html msg
renderBoolWidget m b children = renderHeaderWithChildren m children <|
    div [ class "bool-value" ] [ text (case b of
        True  -> "\u{2714}"
        False -> "\u{274c}"
    ) ]

renderListWidget   : MetaData -> List (Html msg) -> Html msg
renderListWidget m children = renderHeader m <|
    div [ class "list" ] [ renderChildBox children ]

renderUnknownWidget : List (Html msg) -> Html msg
renderUnknownWidget children = renderHeader { noMetaData | key = "unknown_widget" } <|
    div [ class "unknown-widget" ] [ renderChildBox children ]
