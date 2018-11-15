module Ui.Renderer  exposing (..)

import Ui.Tree      exposing (..)
import Contracts    exposing (Properties)

import Html         exposing (Html, div, text)

renderUi : WidgetID -> Widgets -> Properties -> Html WidgetsMsg
renderUi _ _ _ = div [] [ text "I am the ui." ]
