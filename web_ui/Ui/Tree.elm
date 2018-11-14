module Ui.Tree      exposing (..)

import Contracts    exposing (Type, Data, Value, PropertyID, fetch, Callee)
import Ui.MetaData  exposing (..)
import Ui.Action    exposing (..)

import Ui.Widgets.Function

import Dict         exposing (Dict)
import Debug        exposing (crash)

type Tree = Tree Node

type alias Node =
  { key         : String
  , children    : List Tree
  , metaData    : MetaData
  , getter      : Maybe Callee
  , setter      : Maybe Callee
  , subscriber  : Maybe Callee
  , value       : ValueBox
  , widgetID    : WidgetID
  }

type alias WidgetID = Int

type alias Widgets = (Dict Int Widget, Int)

type Children = Children (List Tree)

type ValueBox
  = SimpleValue Value
  | PropertyValue PropertyID
  | NoValue

type Widget
  = FunctionWidget      Ui.Widgets.Function.Model
  | ListWidget
  | StringWidget
  | BoolWidget
  | NumberWidget
  | UnknownWidget

  | SliderWidget
    { min:       Float
    , max:       Float
    , prevValue: Float
    }
  | DelegateWidget      Int
  | BrokenWidget        Int
  | LoadingWidget

type WidgetsMsg
  = UpdateWidget WidgetID WidgetMsg

type WidgetMsg
  = WidgetFixme
  | FunctionMsg Ui.Widgets.Function.Msg

updateWidgets : (Action -> Cmd m) -> (WidgetsMsg -> m) -> WidgetsMsg -> Widgets -> (Widgets, Cmd m)
updateWidgets liftAction liftMsg msg widgets = case msg of
  UpdateWidget id wmsg -> let
      (widget, cmd, actions) = updateWidget wmsg (getWidget id widgets)
    in let
      widgetCmd = Cmd.map liftMsg <| Cmd.map (UpdateWidget id) cmd
      actionCmd = Cmd.batch       <| List.map liftAction actions
    in
      (setWidget id widget widgets, Cmd.batch [widgetCmd, actionCmd])

updateWidget : WidgetMsg -> Widget -> (Widget, Cmd WidgetMsg, List Action)
updateWidget msg widget = case (msg, widget) of
  (WidgetFixme,  ListWidget) -> (widget, Cmd.none, [])
  (FunctionMsg msg, FunctionWidget model) -> let
      (newModel, cmd, actions) = Ui.Widgets.Function.update msg model
    in
      (FunctionWidget newModel, Cmd.map FunctionMsg cmd, actions)
  _ -> crash "widget message of wrong type"

simpleTree : Widgets -> String -> MetaData -> List Tree -> Widget -> ValueBox -> (Tree, Widgets)
simpleTree initialWidgets key metaData children widget v
  = let (widgets, widgetID) = addWidget widget initialWidgets in
    (Tree
      { key         = key
      , metaData    = metaData
      , children    = children
      , getter      = Nothing
      , setter      = Nothing
      , subscriber  = Nothing
      , value       = v
      , widgetID    = widgetID
      }
    , widgets)

addWidget : Widget -> Widgets -> (Widgets, WidgetID)
addWidget w (d, last) = ((Dict.insert last w d, last + 1), last)

getWidget : WidgetID -> Widgets -> Widget
getWidget i (d, _) = fetch i d

replaceWidget : WidgetID -> (Widget -> Widget) -> Widgets -> Widgets
replaceWidget id f (widgets, last) = (Dict.update id (maybify f) widgets, last)

setWidget : WidgetID -> Widget -> Widgets -> Widgets
setWidget id w (widgets, last) = (Dict.insert id w widgets, last)

noWidgets : Widgets
noWidgets = (Dict.empty, 0)

maybify : (a -> b) -> Maybe a -> Maybe b
maybify f x = case x of
  Just t  -> Just <| f t
  Nothing -> Nothing
