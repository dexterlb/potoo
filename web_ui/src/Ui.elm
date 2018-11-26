module Ui exposing (Action, Model, Msg, blank, build, getValue, update, updateProperty, animate, pushResult, view)

import Contracts exposing (Contract, Pid, Properties, PropertyID, fetch)
import Dict exposing (Dict)
import Html exposing (Html)
import Ui.Action
import Ui.Builder exposing (..)
import Ui.Renderer exposing (..)
import Ui.Tree exposing (..)


type alias Model =
    { root : Int
    , widgets : Widgets
    , propertyToWidget : Dict ( Pid, PropertyID ) WidgetID
    , propertyToParent : Dict ( Pid, PropertyID ) WidgetID
    }


type alias Msg =
    WidgetsMsg


type alias Action =
    Ui.Action.Action


build : Int -> Dict Int Contract -> Properties -> Model
build pid contracts properties =
    let
        ( root, widgets ) =
            toTree pid contracts properties
    in
    { root = root
    , widgets = widgets
    , propertyToWidget = propertyMap properties widgets
    , propertyToParent = parentMap properties widgets
    }


blank : Model
blank =
    build 0 Dict.empty Dict.empty


update : (WidgetID -> Action -> Cmd m) -> (Msg -> m) -> Msg -> Model -> ( Model, Cmd m )
update liftAction liftMsg msg m =
    let
        ( widgets, cmd ) =
            updateWidgets liftAction liftMsg msg m.widgets
    in
    ( { m | widgets = widgets }, cmd )


updateProperty : (WidgetID -> Action -> Cmd m) -> (Msg -> m) -> ( Pid, PropertyID ) -> Properties -> Model -> ( Model, Cmd m )
updateProperty liftAction liftMsg ( pid, id ) properties m =
    let
        value =
            properties |> fetch pid |> fetch id |> getValue

        widgetID =
            m.propertyToWidget |> fetch ( pid, id )

        parentID =
            m.propertyToParent |> fetch ( pid, id )
    in
    let
        ( widgets, cmd ) =
            updateWidgetsValue liftAction liftMsg widgetID value m.widgets
    in
    let
        ( widgets2, cmd2 ) =
            updateWidgetsMetaData liftAction liftMsg parentID properties widgets
    in
    ( { m | widgets = widgets2 }, Cmd.batch [ cmd, cmd2 ] )

animate : (Float, Float) -> Model -> Model
animate time m = { m | widgets = animateWidgets time m.widgets }

pushResult : (WidgetID -> Action -> Cmd m) -> (Msg -> m) -> WidgetID -> Ui.Action.ActionResult -> Model -> (Model, Cmd m)
pushResult liftAction liftMsg id result m =
    let
        ( widgets, cmd ) =
            pushResultToWidgets liftAction liftMsg id result m.widgets
    in
    ( { m | widgets = widgets }, cmd )



view : Model -> Html Msg
view { root, widgets } =
    renderUi widgets root


getValue : Contracts.Property -> Contracts.Value
getValue { value } =
    case value of
        Just x ->
            x

        Nothing ->
            Contracts.Loading
