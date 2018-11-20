module Ui.Renderer exposing (renderChildren, renderUi, renderWidget)

import Contracts exposing (Properties, Value(..))
import Html exposing (Html, div, text)
import Ui.Tree exposing (..)

import Ui.Widgets.Simple exposing (..)


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
renderWidget w children = case w of
    StringWidget m (SimpleString s) -> renderStringWidget  m s children
    NumberWidget m (SimpleInt    i) -> renderNumberWidget  m (toFloat i) children
    NumberWidget m (SimpleFloat  f) -> renderNumberWidget  m f children
    BoolWidget   m (SimpleBool   b) -> renderBoolWidget    m b children
    ListWidget   m                  -> renderListWidget    m children
    _                               -> renderUnknownWidget   children
