module Ui.Renderer exposing (renderChildren, renderUi, renderWidget)

import Contracts exposing (Properties)
import Html exposing (Html, div, text)
import Ui.Tree exposing (..)


renderUi : Widgets -> WidgetID -> Html WidgetsMsg
renderUi widgets id =
    let
        ( widget, { children } ) =
            getWidget id widgets
    in
    let
        childrenBox =
            renderChildren children widgets
    in
    renderWidget widget childrenBox


renderChildren : List WidgetID -> Widgets -> List (Html WidgetsMsg)
renderChildren children widgets =
    List.map (renderUi widgets) children


renderWidget : Widget -> List (Html WidgetsMsg) -> Html WidgetsMsg
renderWidget _ children =
    div [] [ text "i am a widget.", div [] children ]
