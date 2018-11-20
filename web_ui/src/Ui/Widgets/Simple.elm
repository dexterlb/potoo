module Ui.Widgets.Simple exposing (..)

import Ui.MetaData exposing (MetaData, noMetaData)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)

renderHeader : MetaData -> Html msg -> Html msg
renderHeader { key, description, uiLevel } body =
    let name = case description of
            ""      -> key
            desc    -> desc
    in let
        level = case uiLevel of
            0 -> "basic"
            1 -> "average"
            _ -> "advanced"
    in
        div [ class "widget", class ("level-" ++ level) ] [
            div [ class "header" ] [ text name ],
            div [ class "body"   ] [ body ]
        ]

renderStringWidget : MetaData -> String -> Html msg
renderStringWidget m v = renderHeader m <|
    div [ class "string-value" ] [ text v ]

renderListWidget   : MetaData -> List (Html msg) -> Html msg
renderListWidget m children = renderHeader m <|
    div [ class "list" ] <|
        List.map (\child -> div [ class "child" ] [ child ]) children

renderUnknownWidget : List (Html msg) -> Html msg
renderUnknownWidget children = renderHeader { noMetaData | key = "unknown_widget" } <|
    div [ class "list" ] <|
        List.map (\child -> div [ class "child" ] [ child ]) children
