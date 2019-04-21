module Ui.Tree exposing (..)

import Contracts exposing (Callee, Data, Pid, PropertyID, Type, Value, fetch)
import Debug
import Dict exposing (Dict)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)
import Ui.Widgets.Function
import Ui.Widgets.Button
import Ui.Widgets.Slider
import Ui.Widgets.Switch
import Ui.Widgets.Choice
import Ui.Widgets.List
import Ui.Widgets.Text


type alias Widgets =
    ( Dict WidgetID ( Widget, Node ), WidgetID )


type Widget
    = FunctionWidget Ui.Widgets.Function.Model
    | ButtonWidget Ui.Widgets.Button.Model
    | SliderWidget Ui.Widgets.Slider.Model
    | SwitchWidget Ui.Widgets.Switch.Model
    | ChoiceWidget Ui.Widgets.Choice.Model
    | ListWidget Ui.Widgets.List.Model
    | TextWidget Ui.Widgets.Text.Model
    | StringWidget MetaData Value
    | NumberWidget MetaData Value
    | UnknownWidget Type MetaData Value
    | DelegateWidget MetaData Int
    | BrokenWidget MetaData Int
    | LoadingWidget MetaData


type WidgetsMsg
    = UpdateWidget WidgetID WidgetMsg


type WidgetMsg
    = FunctionMsg Ui.Widgets.Function.Msg
    | ButtonMsg Ui.Widgets.Button.Msg
    | SliderMsg Ui.Widgets.Slider.Msg
    | SwitchMsg Ui.Widgets.Switch.Msg
    | ChoiceMsg Ui.Widgets.Choice.Msg
    | TextMsg Ui.Widgets.Text.Msg
    | ListMsg   Ui.Widgets.List.Msg


type alias Node =
    { key : String
    , metaMaker : Contracts.Properties -> MetaData
    , children : List WidgetID
    }


type alias WidgetID =
    Int


updateWidgets : (WidgetID -> Action -> Cmd m) -> (WidgetsMsg -> m) -> WidgetsMsg -> Widgets -> ( Widgets, Cmd m )
updateWidgets liftAction liftMsg msg widgets =
    case msg of
        UpdateWidget id wmsg ->
            updateWidget wmsg (getWidget id widgets)
                |> liftUpdateResult id widgets (liftAction id) liftMsg

pushResultToWidgets : (WidgetID -> Action -> Cmd m) -> (WidgetsMsg -> m) -> WidgetID -> ActionResult -> Widgets -> ( Widgets, Cmd m )
pushResultToWidgets liftAction liftMsg id result widgets =
    pushResultToWidget result (getWidget id widgets)
        |> liftUpdateResult id widgets (liftAction id) liftMsg


updateWidgetsValue : (WidgetID -> Action -> Cmd m) -> (WidgetsMsg -> m) -> WidgetID -> Value -> Widgets -> ( Widgets, Cmd m )
updateWidgetsValue liftAction liftMsg id value widgets =
    updateWidgetValue value (getWidget id widgets) |> liftUpdateResult id widgets (liftAction id) liftMsg


updateWidgetsMetaData : (WidgetID -> Action -> Cmd m) -> (WidgetsMsg -> m) -> WidgetID -> Contracts.Properties -> Widgets -> ( Widgets, Cmd m )
updateWidgetsMetaData liftAction liftMsg id properties widgets =
    let
        widget =
            getWidget id widgets
    in
    let
        ( _, { metaMaker } ) =
            widget
    in
    let
        meta =
            metaMaker properties
    in
    updateWidgetMetaData meta (getWidget id widgets) |> liftUpdateResult id widgets (liftAction id) liftMsg


animateWidgets : (Float, Float) -> Widgets -> Widgets
animateWidgets time widgets = mapToWidgets (animateWidget time) widgets

liftUpdateResult : WidgetID -> Widgets -> (Action -> Cmd m) -> (WidgetsMsg -> m) -> ( Widget, Cmd WidgetMsg, List Action ) -> ( Widgets, Cmd m )
liftUpdateResult id widgets liftAction liftMsg ( widget, cmd, actions ) =
    let
        widgetCmd =
            Cmd.map liftMsg <| Cmd.map (UpdateWidget id) cmd

        actionCmd =
            Cmd.batch <| List.map liftAction actions
    in
    ( setWidget id widget widgets, Cmd.batch [ widgetCmd, actionCmd ] )


updateWidget : WidgetMsg -> ( Widget, Node ) -> ( Widget, Cmd WidgetMsg, List Action )
updateWidget outerMsg ( widget, node ) =
    case ( outerMsg, widget ) of
        ( FunctionMsg msg, FunctionWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Function.update msg model
            in
                ( FunctionWidget newModel, Cmd.map FunctionMsg cmd, actions )

        ( ButtonMsg msg, ButtonWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Button.update msg model
            in
                ( ButtonWidget newModel, Cmd.map ButtonMsg cmd, actions )

        ( SliderMsg msg, SliderWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Slider.update msg model
            in
                ( SliderWidget newModel, Cmd.map SliderMsg cmd, actions )

        ( SwitchMsg msg, SwitchWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Switch.update msg model
            in
                ( SwitchWidget newModel, Cmd.map SwitchMsg cmd, actions )

        ( ChoiceMsg msg, ChoiceWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Choice.update msg model
            in
                ( ChoiceWidget newModel, Cmd.map ChoiceMsg cmd, actions )

        ( TextMsg msg, TextWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Text.update msg model
            in
                ( TextWidget newModel, Cmd.map TextMsg cmd, actions )


        ( ListMsg msg, ListWidget model ) ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.List.update msg model
            in
                ( ListWidget newModel, Cmd.map ListMsg cmd, actions )

        _ ->
            Debug.todo "widget message of wrong type"

animateWidget : (Float, Float) -> Widget -> Widget
animateWidget time widget = case widget of
    SliderWidget model -> SliderWidget <| Ui.Widgets.Slider.animate time model
    _ -> widget

pushResultToWidget : ActionResult -> ( Widget, Node ) -> ( Widget, Cmd WidgetMsg, List Action )
pushResultToWidget result ( widget, node ) =
    case widget of
        FunctionWidget model ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Function.pushResult result model
            in
                ( FunctionWidget newModel, Cmd.map FunctionMsg cmd, actions )

        ButtonWidget model ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Button.pushResult result model
            in
                ( ButtonWidget newModel, Cmd.map ButtonMsg cmd, actions )

        _ ->
            Debug.todo "widget of wrong type"


updateWidgetValue : Value -> ( Widget, Node ) -> ( Widget, Cmd WidgetMsg, List Action )
updateWidgetValue v ( widget, node ) =
    case widget of
        StringWidget meta _ ->
            ( StringWidget meta v, Cmd.none, [] )

        NumberWidget meta _ ->
            ( NumberWidget meta v, Cmd.none, [] )

        UnknownWidget typ meta _ ->
            ( UnknownWidget typ meta v, Cmd.none, [] )

        SwitchWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Switch.updateValue v m
            in
            ( SwitchWidget newModel, Cmd.map SwitchMsg cmd, actions )

        ChoiceWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Choice.updateValue (Contracts.encodeValue v) m
            in
            ( ChoiceWidget newModel, Cmd.map ChoiceMsg cmd, actions )

        TextWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Text.updateValue v m
            in
            ( TextWidget newModel, Cmd.map TextMsg cmd, actions )

        SliderWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Slider.updateValue v m
            in
            ( SliderWidget newModel, Cmd.map SliderMsg cmd, actions )

        _ ->
            Debug.todo "trying to update unupdatable widget"


updateWidgetMetaData : MetaData -> ( Widget, Node ) -> ( Widget, Cmd WidgetMsg, List Action )
updateWidgetMetaData meta ( widget, node ) =
    case widget of
        StringWidget _ v ->
            ( StringWidget meta v, Cmd.none, [] )

        NumberWidget _ v ->
            ( NumberWidget meta v, Cmd.none, [] )

        UnknownWidget typ _ v ->
            ( UnknownWidget typ meta v, Cmd.none, [] )

        DelegateWidget _ v ->
            ( DelegateWidget meta v, Cmd.none, [] )

        BrokenWidget _ v ->
            ( BrokenWidget meta v, Cmd.none, [] )

        ListWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.List.updateMetaData meta m
            in
                ( ListWidget newModel, Cmd.map ListMsg cmd, actions )

        LoadingWidget _ ->
            ( LoadingWidget meta, Cmd.none, [] )

        FunctionWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Function.updateMetaData meta m
            in
            ( FunctionWidget newModel, Cmd.map FunctionMsg cmd, actions )

        ButtonWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Button.updateMetaData meta m
            in
            ( ButtonWidget newModel, Cmd.map ButtonMsg cmd, actions )

        SliderWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Slider.updateMetaData meta m
            in
            ( SliderWidget newModel, Cmd.map SliderMsg cmd, actions )

        SwitchWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Switch.updateMetaData meta m
            in
            ( SwitchWidget newModel, Cmd.map SwitchMsg cmd, actions )

        ChoiceWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Choice.updateMetaData meta m
            in
            ( ChoiceWidget newModel, Cmd.map ChoiceMsg cmd, actions )

        TextWidget m ->
            let
                ( newModel, cmd, actions ) =
                    Ui.Widgets.Text.updateMetaData meta m
            in
            ( TextWidget newModel, Cmd.map TextMsg cmd, actions )


simpleTree : Widgets -> String -> (Contracts.Properties -> MetaData) -> List WidgetID -> Widget -> ( WidgetID, Widgets )
simpleTree initialWidgets key metaMaker children widget =
    let
        node =
            { key = key
            , metaMaker = metaMaker
            , children = children
            }
    in
    addWidget ( widget, node ) initialWidgets


addWidget : ( Widget, Node ) -> Widgets -> ( WidgetID, Widgets )
addWidget w ( d, last ) =
    ( last, ( Dict.insert last w d, last + 1 ) )


getWidget : WidgetID -> Widgets -> ( Widget, Node )
getWidget i ( d, _ ) =
    fetch i d


replaceWidget : WidgetID -> (( Widget, Node ) -> ( Widget, Node )) -> Widgets -> Widgets
replaceWidget id f ( widgets, last ) =
    ( Dict.update id (Maybe.map f) widgets, last )


setWidget : WidgetID -> Widget -> Widgets -> Widgets
setWidget id w ( widgets, last ) =
    ( Dict.update id (Maybe.map (\( _, n ) -> ( w, n ))) widgets, last )

mapToWidgets : (Widget -> Widget) -> Widgets -> Widgets
mapToWidgets f (widgets, last) = (Dict.map (\k (w, n) -> (f w, n)) widgets, last)


noWidgets : Widgets
noWidgets =
    ( Dict.empty, 0 )
