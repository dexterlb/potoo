module Ui.Builder exposing (parentMap, propertyMap, toTree)

import Contracts exposing (Contract, Pid, Properties, PropertyID, fetch, makeCallee)
import Dict exposing (Dict)
import Ui.MetaData exposing (..)
import Ui.Tree exposing (..)
import Ui.Widgets.Function
import Ui.Widgets.Slider
import Ui.Widgets.Switch


toTree : Pid -> Dict Pid Contract -> Properties -> ( WidgetID, Widgets )
toTree pid contracts properties =
    case Dict.get pid contracts of
        Just contract ->
            toTree_ contract "root" pid contracts properties noWidgets

        Nothing ->
            let
                meta =
                    { noMetaData | key = "root" }
            in
            simpleTree noWidgets "root" (\_ -> meta) [] (BrokenWidget meta pid)


toTree_ : Contract -> String -> Pid -> Dict Pid Contract -> Properties -> Widgets -> ( WidgetID, Widgets )
toTree_ c key pid contracts properties widgets =
    let
        metaMaker =
            getMetaData key c pid
    in
    let
        metaData =
            metaMaker properties
    in
    case c of
        Contracts.StringValue s ->
            simpleTree widgets key metaMaker [] (StringWidget metaData <| Contracts.SimpleString s)

        Contracts.IntValue x ->
            simpleTree widgets key metaMaker [] (NumberWidget metaData <| Contracts.SimpleInt x)

        Contracts.FloatValue x ->
            simpleTree widgets key metaMaker [] (NumberWidget metaData <| Contracts.SimpleFloat x)

        Contracts.BoolValue x ->
            simpleTree widgets key metaMaker [] (SwitchWidget <|
                Ui.Widgets.Switch.init metaData <| Contracts.SimpleBool x)

        Contracts.Function { argument, name, retval, data } ->
            simpleTree widgets
                key
                metaMaker
                []
                (FunctionWidget <|
                    Ui.Widgets.Function.init
                        metaData
                        { argument = argument, name = name, retval = retval, pid = pid }
                )

        Contracts.Delegate { destination, data } ->
            let
                ( widget, children, widgets2 ) =
                    case Dict.get destination contracts of
                        Just subcontract ->
                            let
                                ( child, widgets3 ) =
                                    toTree_ subcontract "connected" destination contracts properties widgets
                            in
                            ( DelegateWidget metaData destination
                            , [ child ]
                            , widgets3
                            )

                        Nothing ->
                            ( BrokenWidget metaData pid, [], widgets )
            in
            simpleTree widgets2 key metaMaker children widget

        Contracts.MapContract d ->
            let
                ( children, newWidgets ) =
                    Dict.map (\subkey subcontract -> ( subcontract, subkey, pid )) d
                        |> Dict.values
                        |> toTreeMany contracts properties widgets
            in
            simpleTree newWidgets key metaMaker children (ListWidget metaData)

        Contracts.ListContract d ->
            let
                ( children, newWidgets ) =
                    List.indexedMap (\i subcontract -> ( subcontract, "#" ++ String.fromInt i, pid )) d |> toTreeMany contracts properties widgets
            in
            simpleTree newWidgets key metaMaker children (ListWidget metaData)

        Contracts.PropertyKey propertyID (Contracts.MapContract d) ->
            let
                ( children, newWidgets ) =
                    Dict.map
                        (\subkey subcontract ->
                            ( subcontract, subkey, pid )
                        )
                        d
                        |> Dict.values
                        |> toTreeMany contracts properties widgets

                property =
                    properties |> fetch pid |> fetch propertyID
            in
            let
                node =
                    { key = key
                    , metaMaker = metaMaker
                    , children = children
                    }
            in
            addWidget ( propertyWidget property metaData, node ) newWidgets

        Contracts.PropertyKey _ subcontract ->
            toTree_ subcontract key pid contracts properties widgets


toTreeMany : Dict Pid Contract -> Properties -> Widgets -> List ( Contract, String, Pid ) -> ( List WidgetID, Widgets )
toTreeMany contracts properties initialWidgets l =
    List.foldr
        (\( c, key, pid ) ( trees, widgets ) -> toTree_ c key pid contracts properties widgets |> (\( t, w ) -> ( t :: trees, w )))
        ( [], initialWidgets )
        l


propertyWidget : Contracts.Property -> MetaData -> Widget
propertyWidget prop metaData =
    case Contracts.stripType prop.propertyType of
        Contracts.TFloat ->
            case Contracts.getMinMax prop of
                -- todo: parse type here instead of using barbaric getMinMax
                Just ( min, max ) ->
                    SliderWidget <| Ui.Widgets.Slider.init metaData Contracts.Loading { min = min, max = max, step = 0.01, speed = 1 }

                Nothing ->
                    NumberWidget metaData Contracts.Loading

        Contracts.TInt ->
            NumberWidget metaData Contracts.Loading

        Contracts.TString ->
            StringWidget metaData Contracts.Loading

        Contracts.TBool -> SwitchWidget <|
            Ui.Widgets.Switch.init metaData Contracts.Loading

        _ ->
            UnknownWidget metaData Contracts.Loading


propertyMap : Properties -> Widgets -> Dict ( Pid, PropertyID ) WidgetID
propertyMap properties ( w, _ ) =
    w
        |> Dict.toList
        |> List.map (\( id, ( _, { metaMaker } ) ) -> ( metaMaker properties, id ))
        |> List.map (\( meta, id ) -> ( meta.propData.property, id ))
        |> Dict.fromList


parentMap : Properties -> Widgets -> Dict ( Pid, PropertyID ) WidgetID
parentMap properties ( w, l ) =
    w
        |> Dict.toList
        |> List.concatMap (\( id, ( _, { children } ) ) -> List.map (\child -> ( child, id )) children)
        |> List.map (\( child, id ) -> ( getWidget child ( w, l ), id ))
        |> List.map (\( ( _, { metaMaker } ), id ) -> ( metaMaker properties, id ))
        |> List.map (\( meta, id ) -> ( meta.propData.property, id ))
        |> Dict.fromList
