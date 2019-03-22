module Ui.Renderer exposing (renderChildren, renderUi, renderWidget)

import Contracts exposing (Value(..))
import Html exposing (Html, div, text)
import Ui.Tree exposing (..)

import Ui.Widgets.Simple exposing (..)
import Ui.Widgets.Function as Function
import Ui.Widgets.Button   as Button
import Ui.Widgets.Slider   as Slider
import Ui.Widgets.Switch   as Switch
import Ui.Widgets.List


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
    renderWidget (UpdateWidget id) widget childrenBox


renderChildren : List WidgetID -> Widgets -> List (Html WidgetsMsg)
renderChildren children widgets =
    List.map (renderUi widgets) children


renderWidget : (WidgetMsg -> WidgetsMsg) -> Widget -> List (Html WidgetsMsg) -> Html WidgetsMsg
renderWidget lift w children = case w of
    StringWidget   m (SimpleString s) -> renderStringWidget   m s children
    NumberWidget   m (SimpleInt    i) -> renderNumberWidget   m (toFloat i) children
    NumberWidget   m (SimpleFloat  f) -> renderNumberWidget   m f children
    DelegateWidget m pid              -> renderDelegateWidget m pid children
    BrokenWidget   m pid              -> renderBrokenWidget   m pid
    ListWidget     model              -> Ui.Widgets.List.view     (lift << ListMsg)     model children
    FunctionWidget model              -> Function.view (lift << FunctionMsg) model children
    ButtonWidget   model              -> Button.view   (lift << ButtonMsg)   model children
    SwitchWidget   model              -> Switch.view   (lift << SwitchMsg  ) model children
    SliderWidget   model              -> Slider.view   (lift << SliderMsg  ) model children
    _                                 -> renderUnknownWidget   children
