module Ui.Tree exposing (..)

import Contracts exposing (Type, Data, Value, PropertyID, fetch)
import Ui.MetaData exposing (..)

import Dict exposing (Dict)

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

type alias Callee =
  { argument: Type
  , name: String
  , retval: Type
  , pid: Int
  }

type ValueBox
  = SimpleValue Value
  | PropertyValue PropertyID
  | NoValue

type Widget
  = FunctionWidget      Callee
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

noWidgets : Widgets
noWidgets = (Dict.empty, 0)

makeCallee : Int -> Contracts.FunctionStruct -> Callee
makeCallee pid { argument, retval, name }
 = { argument = argument
   , name     = name
   , retval   = retval
   , pid      = pid
   }
