module Ui exposing (..)

import Ui.Tree exposing (..)
import Ui.Builder exposing (..)

import Contracts
import Contracts exposing (Contract, Properties, fetch)

import Dict
import Dict exposing(Dict)

type alias Ui =
  { tree: Tree
  , widgets: Widgets
  }

build : Int -> Dict Int Contract -> Properties -> Ui
build pid contracts properties = let (tree, widgets) = toTree pid contracts properties
  in { tree = tree, widgets = widgets }

blank : Ui
blank = build 0 Dict.empty Dict.empty
