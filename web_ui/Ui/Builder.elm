module Ui.Builder exposing (toTree)

import Ui.Tree exposing(..)
import Ui.MetaData exposing(..)

import Contracts
import Contracts exposing (Contract, Properties, fetch)

import Dict
import Dict exposing(Dict)

toTree : Int -> Dict Int Contract -> Properties -> (Tree, Widgets)
toTree pid contracts properties  = case Dict.get pid contracts of
  (Just contract) -> toTree_ contract "root" pid contracts properties noWidgets
  Nothing -> simpleTree noWidgets "root" (noMetaData "root") [] (BrokenWidget pid) NoValue

toTree_ : Contract -> String -> Int -> Dict Int Contract -> Properties -> Widgets -> (Tree, Widgets)
toTree_ c key pid contracts properties widgets = let metaData = getMetaData key c pid properties in
  case c of
    Contracts.StringValue s -> simpleTree widgets key metaData [] StringWidget  (SimpleValue <| Contracts.SimpleString s)
    Contracts.IntValue x    -> simpleTree widgets key metaData [] NumberWidget  (SimpleValue <| Contracts.SimpleInt x)
    Contracts.FloatValue x  -> simpleTree widgets key metaData [] NumberWidget  (SimpleValue <| Contracts.SimpleFloat x)
    Contracts.BoolValue x   -> simpleTree widgets key metaData [] BoolWidget    (SimpleValue <| Contracts.SimpleBool x)
    Contracts.Function { argument, name, retval, data } -> simpleTree widgets key
      metaData []
      (FunctionWidget { argument = argument, name = name, retval = retval, pid = pid })
      NoValue
    Contracts.Delegate { destination, data } ->
        let (children, widget, widgets2) = case Dict.get destination contracts of
          (Just subcontract) ->
            let (child, widgets3) = toTree_ subcontract "connected" destination contracts properties widgets in
              ( [ child ]
              , DelegateWidget destination
              , widgets3)
          Nothing -> ([], BrokenWidget pid, widgets)
        in simpleTree widgets2 key metaData children widget NoValue
    Contracts.MapContract d -> let (children, newWidgets) = Dict.map (\ subkey subcontract -> (subcontract, subkey, pid)) d
        |> Dict.values |> toTreeMany contracts properties widgets
      in simpleTree newWidgets key metaData children ListWidget NoValue
    Contracts.ListContract d -> let (children, newWidgets) = List.indexedMap (\ i subcontract -> (subcontract, "#" ++ (toString i), pid)) d |> toTreeMany contracts properties widgets
      in simpleTree newWidgets key metaData children ListWidget NoValue
    Contracts.PropertyKey propertyID (Contracts.MapContract d) -> let
        (children, newWidgets) = Dict.map (\ subkey subcontract
          -> (subcontract, subkey, pid)) d
          |> Dict.values |> toTreeMany contracts properties widgets
        property -- todo: those need to be stored in contract
          = properties |> fetch pid |> fetch propertyID
      in let
        { getter, setter, subscriber, propertyType, value } = property
        (newWidgets, widget) = addWidget (propertyWidget property metaData) widgets
      in
        ( Tree
          { key         = key
          , metaData    = metaData
          , children    = children
          , getter      = Maybe.map (makeCallee pid) getter
          , setter      = Maybe.map (makeCallee pid) setter
          , subscriber  = Maybe.map (makeCallee pid) subscriber
          , value       = PropertyValue propertyID
          , widgetID    = widget
          }
        , newWidgets
        )
    Contracts.PropertyKey _ subcontract -> toTree_ subcontract key pid contracts properties widgets

toTreeMany : Dict Int Contract -> Properties -> Widgets -> List (Contract, String, Int) -> (List Tree, Widgets)
toTreeMany contracts properties initialWidgets l
  = List.foldr
    (\(c, key, pid) (trees, widgets) -> ((toTree_ c key pid contracts properties widgets) |> (\(t, w) -> (t :: trees, w))))
    ([], initialWidgets) l

propertyWidget : Contracts.Property -> MetaData -> Widget
propertyWidget prop _ = case (Contracts.stripType prop.propertyType) of
  Contracts.TFloat -> case Contracts.getMinMax prop of
    -- todo: parse type here instead of using barbaric getMinMax
    Just (min, max) -> SliderWidget { min = min, max = max, prevValue = 0 }
    Nothing         -> NumberWidget
  Contracts.TInt    -> NumberWidget
  Contracts.TString -> StringWidget
  Contracts.TBool   -> BoolWidget
  _                 -> UnknownWidget
