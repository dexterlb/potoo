module Ui.Renderer  exposing (..)

import Ui.Tree      exposing (..)
import Contracts    exposing (Properties)

import Html         exposing (Html, div, text)

renderUi : Widgets -> WidgetID -> Html WidgetsMsg
renderUi widgets id = let (widget, { children }) = getWidget id widgets in
  let childrenBox = renderChildren children widgets in
    renderWidget widget childrenBox

renderChildren : List WidgetID -> Widgets -> Html WidgetsMsg
renderChildren children widgets = div []
  <| List.map (renderUi widgets) children

renderWidget : Widget -> Html WidgetsMsg -> Html WidgetsMsg
renderWidget _ children = div [] [ text "i am a widget.", children ]
