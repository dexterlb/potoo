module Main exposing (main)

import Api exposing (..)
import Browser exposing (UrlRequest)
import Contracts exposing (..)
import Debug exposing (log)
import Delay
import Dict exposing (Dict)
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attrs exposing (class, css, href, src, title)
import Html.Styled.Events exposing (onClick, onInput)
import Html.Styled.Keyed
import Json.Decode
import Json.Encode
import Modes exposing (..)
import Random
import Random.Char
import Random.String
import Set exposing (Set)
import Styles
import Ui
import Ui.Action
import Ui.MetaData exposing (..)
import Animation
import Url exposing (Url)
import Url.Parser as UP
import Url.Parser exposing ((</>))
import Browser
import Browser exposing (UrlRequest, Document)
import Browser.Navigation exposing (Key)


main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- MODEL


type alias Model =
    { input : String
    , messages : List String
    , conn : Conn
    , mode : Mode
    , url : Url
    , contracts : Dict Int Contract
    , allProperties : Properties
    , fetchingContracts : Set Int
    , status : Status
    , toCall : Maybe VisualContract
    , callToken : Maybe String
    , callArgument : Maybe Json.Encode.Value
    , callResult : Maybe Json.Encode.Value
    , ui : Ui.Model
    , key: Key
    , animationTime: Float
    }


init : Json.Encode.Value -> Url -> Key -> ( Model, Cmd Msg )
init _ url key = let model = emptyModel url key Connecting
    in (model , startCommand model)


startCommand : Model -> Cmd Msg
startCommand model =
    Cmd.batch
        [ nextPing
        , Api.connect "main" <| connectionUrl model.url
        ]


emptyModel : Url -> Key -> Status -> Model
emptyModel url key status =
    { input = ""
    , messages = []
    , conn = "main"
    , mode = parseMode url
    , url = url
    , key = key
    , status = status
    , contracts = Dict.empty
    , allProperties = Dict.empty
    , fetchingContracts = Set.empty
    , toCall = Nothing
    , callToken = Nothing
    , callArgument = Nothing
    , callResult = Nothing
    , ui = Ui.blank
    , animationTime = 0
    }

type Status
  = Connecting
  | Reconnecting
  | JollyGood

parseMode : Url -> Mode
parseMode url = UP.parse modeParser url |> Maybe.withDefault Basic

modeParser : UP.Parser (Mode -> a) a
modeParser = UP.fragment fragmentParser

fragmentParser : Maybe String -> Mode
fragmentParser s = case s of
    Just "advanced" -> Advanced
    _               -> Basic

connectionUrl : Url -> Conn
connectionUrl { host, port_ } =
    let authority = (case port_ of
            Nothing -> host
            (Just p)  -> host ++ ":" ++ (String.fromInt p))
    in
        ("ws://" ++ authority ++ "/ws")



-- UPDATE


type Msg
    = SocketMessage Api.Msg
    | AskCall VisualContract
    | AskInstantCall VisualContract
    | ActionCall VisualContract
    | CallArgumentInput String
    | PerformCall { target : DelegateStruct, name : String, argument : Json.Encode.Value }
    | PerformCallWithToken { target : DelegateStruct, name : String, argument : Json.Encode.Value } String
    | CancelCall
    | CallGetter ( Pid, PropertyID ) FunctionStruct
    | CallSetter ( Pid, PropertyID ) FunctionStruct Json.Encode.Value
    | SendPing
    | UrlChanged Url
    | UrlRequested UrlRequest
    | UiMsg Ui.Msg
    | Animate Float


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SocketMessage (Ok (_, resp)) ->
            handleResponse model resp
        SocketMessage (Err err) ->
            let
                errMsg = Debug.log "error" <|
                    "unable to parse response: " ++ err
            in
            ( { model | messages = errMsg :: model.messages }, Cmd.none )

        AskCall f ->
            ( { model | toCall = Just f, callToken = Nothing, callArgument = Nothing, callResult = Nothing }, Cmd.none )

        AskInstantCall f ->
            ( { model | toCall = Just f, callArgument = Just Json.Encode.null }, instantCall f )

        ActionCall f ->
            ( model, actionCall model f )

        CallArgumentInput input ->
            ( { model | callArgument = checkCallInput input }, Cmd.none )

        PerformCall data ->
            ( model, performCall data )

        PerformCallWithToken data token ->
            ( { model | callToken = Just token }, Api.unsafeCall model.conn data token )

        CancelCall ->
            ( { model
                | toCall = Nothing
                , callToken = Nothing
                , callArgument = Nothing
                , callResult = Nothing
              }
            , Cmd.none
            )

        CallGetter ( pid, id ) { name } ->
            ( model
            , Api.getterCall model.conn
                { target = delegate pid, name = name, argument = Json.Encode.null }
                ( pid, id )
            )

        CallSetter ( pid, id ) { name } value ->
            ( model
            , Api.setterCall model.conn
                { target = delegate pid, name = name, argument = value }
                ( pid, id )
            )

        SendPing ->
            ( model, Cmd.batch [ sendPing model.conn, nextPing ] )

        UrlChanged url -> let newModel = emptyModel url model.key Connecting in
            ( newModel, startCommand newModel )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Browser.Navigation.pushUrl model.key (Url.toString url)
                    )

                Browser.External url ->
                    ( model
                    , Browser.Navigation.load url
                    )

        UiMsg uiMsg ->
            let
                ( newUi, cmd ) =
                    Ui.update (handleUiAction model) UiMsg uiMsg model.ui
            in
            ( { model | ui = newUi }, cmd )

        Animate time -> let diff = time - model.animationTime in
            ( { model | ui = Ui.animate (time, diff) model.ui, animationTime = time } , Cmd.none )


nextPing : Cmd Msg
nextPing =
    Delay.after 5 Delay.Second SendPing


handleUiAction : Model -> Int -> Ui.Action -> Cmd Msg
handleUiAction m id action =
    case action of
        Ui.Action.RequestCall { name, pid } argument token ->
            Api.unsafeCall m.conn
                { target = { destination = pid, data = emptyData }
                , name = name
                , argument = argument
                } (String.fromInt id ++ ":" ++ token)
        Ui.Action.RequestSet (pid, propertyID) value ->
            case m.allProperties |> fetch pid |> fetch propertyID |> (\x -> x.setter) of
                Just { name } ->
                    Api.setterCall m.conn
                        { target = delegate pid
                        , name = name
                        , argument = value
                        } (pid, propertyID)
                Nothing -> Cmd.none
        Ui.Action.RequestGet (pid, propertyID) value ->
            case m.allProperties |> fetch pid |> fetch propertyID |> (\x -> x.getter) of
                Just { name } ->
                    Api.getterCall m.conn
                        { target = delegate pid
                        , name = name
                        , argument = value
                        } (pid, propertyID)
                Nothing -> Cmd.none

instantCall : VisualContract -> Cmd Msg
instantCall vc =
    case vc of
        VFunction { argument, name, retval, data, pid } ->
            performCall { target = delegate pid, name = name, argument = Json.Encode.null }

        _ ->
            Cmd.none


actionCall : Model -> VisualContract -> Cmd Msg
actionCall model vc =
    case vc of
        VFunction { argument, name, retval, data, pid } ->
            Api.actionCall model.conn { target = delegate pid, name = name, argument = Json.Encode.null }

        _ ->
            Cmd.none


performCall : { target : DelegateStruct, name : String, argument : Json.Encode.Value } -> Cmd Msg
performCall data =
    Random.generate
        (PerformCallWithToken data)
        (Random.String.string 64 Random.Char.english)


handleResponse : Model -> Response -> ( Model, Cmd Msg )
handleResponse m resp =
    case resp of
        GotContract pid contract ->
            updateUiCmd <|
                let
                    ( newContract, properties ) =
                        propertify contract

                    ( newModel, newCommand ) =
                        checkMissing newContract
                            { m
                                | allProperties = Dict.insert pid properties m.allProperties
                                , contracts = Dict.insert pid newContract m.contracts
                                , fetchingContracts = Set.remove pid m.fetchingContracts
                            }
                in
                ( newModel
                , Cmd.batch
                    [ subscribeProperties m.conn pid properties
                    , newCommand
                    ]
                )

        UnsafeCallResult token value ->
            case m.callToken of
                Just actualToken ->
                    case token == actualToken of
                        True ->
                            ( { m | callResult = Just value }, Cmd.none )
                        False ->
                            ( m, Cmd.none )
                Nothing ->
                    case String.split ":" token of
                        [ h, t ] -> case String.toInt h of
                            Just id -> pushUiResult id (Ui.Action.CallResult value t) m
                            _ -> ( m, Cmd.none )
                        _ -> ( m, Cmd.none )

        ValueResult ( pid, propertyID ) value ->
            updateUiProperty ( pid, propertyID ) <|
                ( { m
                    | allProperties =
                        m.allProperties
                            |> Dict.update pid
                                (Maybe.map <|
                                    Dict.update propertyID
                                        (Maybe.map <|
                                            setValue value
                                        )
                                )
                  }
                , Cmd.none
                )

        ChannelResult token chan ->
            ( m, subscribe m.conn chan token )

        SubscribedChannel token ->
            ( Debug.log (Json.Encode.encode 0 token) m, Cmd.none )

        PropertySetterStatus _ status ->
            ( Debug.log ("property setter status: " ++ Json.Encode.encode 0 status) m, Cmd.none )

        Pong ->
            ( m, Cmd.none )

        Hello ->
            ( emptyModel m.url m.key JollyGood, Api.getContract m.conn (delegate 0) )

        Connected ->
            ( emptyModel m.url m.key JollyGood, Cmd.none )

        Disconnected ->
            ( { m | status = Reconnecting }, Cmd.none )


subscribeProperties : Conn -> Pid -> ContractProperties -> Cmd Msg
subscribeProperties conn pid properties =
    Dict.toList properties
        |> List.map (foo conn pid)
        |> Cmd.batch


foo : Conn -> Pid -> ( PropertyID, Property ) -> Cmd Msg
foo conn pid ( id, prop ) =
    case prop.subscriber of
        Nothing ->
            Cmd.none

        Just setter ->
            Cmd.batch
                [ subscriberCall conn
                    { target = delegate pid, name = setter.name, argument = Json.Encode.null }
                    ( pid, id )
                , case prop.getter of
                    Nothing ->
                        Cmd.none

                    Just getter ->
                        getterCall conn
                            { target = delegate pid, name = getter.name, argument = Json.Encode.null }
                            ( pid, id )
                ]


setValue : Json.Encode.Value -> Property -> Property
setValue v prop =
    case decodeValue v prop of
        Ok value ->
            { prop | value = Just value }

        Err _ ->
            { prop | value = Just <| Complex v }


decodeValue : Json.Encode.Value -> Property -> Result Json.Decode.Error Value
decodeValue v prop = Json.Decode.decodeValue
    (case stripType prop.propertyType of
        TFloat ->
            Json.Decode.float
                |> Json.Decode.map SimpleFloat
        TBool ->
            Json.Decode.bool
                |> Json.Decode.map SimpleBool
        TInt ->
            Json.Decode.int
                |> Json.Decode.map SimpleInt
        TString ->
            Json.Decode.string
                |> Json.Decode.map SimpleString
        _ ->
            Json.Decode.fail "unknown property type"
    ) v


checkMissing : Contract -> Model -> ( Model, Cmd Msg )
checkMissing c m =
    let
        missing =
            Set.diff (delegatePids c |> Set.fromList) m.fetchingContracts

        newModel =
            { m | fetchingContracts = Set.union m.fetchingContracts missing }

        command =
            missing |> Set.toList |> List.map delegate |> List.map (Api.getContract m.conn) |> Cmd.batch
    in
    ( newModel, command )


delegatePids : Contract -> List Int
delegatePids contract =
    case contract of
        MapContract d ->
            Dict.values d
                |> List.concatMap delegatePids

        ListContract l ->
            l |> List.concatMap delegatePids

        Delegate { destination } ->
            [ destination ]

        _ ->
            []


checkCallInput : String -> Maybe Json.Encode.Value
checkCallInput s =
    case Json.Decode.decodeString Json.Decode.value s of
        Ok v ->
            Just v

        _ ->
            Nothing


updateUi : Model -> Model
updateUi m =
    { m | ui = Ui.build 0 m.contracts m.allProperties }


updateUiCmd : ( Model, a ) -> ( Model, a )
updateUiCmd ( m, x ) =
    ( updateUi m, x )

pushUiResult : Int -> Ui.Action.ActionResult -> Model -> (Model, Cmd Msg)
pushUiResult id result m =
    let
        (uiModel, cmd) = Ui.pushResult (handleUiAction m) UiMsg id result m.ui
    in
        ( { m | ui = uiModel }, cmd )



updateUiProperty : ( Pid, PropertyID ) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updateUiProperty prop ( m, x ) =
    let
        ( uiModel, cmd ) =
            Ui.updateProperty (handleUiAction m) UiMsg prop m.allProperties m.ui
    in
    ( { m | ui = uiModel }, Cmd.batch [ x, cmd ] )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ = Sub.batch
    [ Api.subscriptions SocketMessage
    , Animation.times   Animate
    ]




-- VIEW


metaData : VisualContract -> String -> MetaData
metaData vc name =
    case vc of
        VFunction { data } ->
            dataMetaData name data

        VConnectedDelegate { data } ->
            dataMetaData name data

        VBrokenDelegate { data } ->
            dataMetaData name data

        VMapContract d ->
            MetaData
                name
                noPropData
                (Dict.get "ui_level" d |> Maybe.map valueOf |> Maybe.andThen getIntValue |> Maybe.withDefault 0)
                (Dict.get "description" d |> Maybe.map valueOf |> Maybe.andThen getStringValue |> Maybe.withDefault name)
                (Dict.get "enabled" d |> Maybe.map valueOf |> Maybe.andThen getBoolValue |> Maybe.withDefault True)
                []
                emptyData

        VStringValue _ ->
            case isMeta name of
                True ->
                    MetaData name noPropData 1 name True [] emptyData

                False ->
                    MetaData name noPropData 0 name True [] emptyData

        VBoolValue _ ->
            case isMeta name of
                True ->
                    MetaData name noPropData 1 name True [] emptyData

                False ->
                    MetaData name noPropData 0 name True [] emptyData

        VIntValue _ ->
            case isMeta name of
                True ->
                    MetaData name noPropData 1 name True [] emptyData

                False ->
                    MetaData name noPropData 0 name True [] emptyData

        VProperty { contract } ->
            metaData contract name

        _ ->
            MetaData name noPropData 0 name True [] emptyData


isMeta : String -> Bool
isMeta s =
    case s of
        "description" ->
            True

        "ui_level" ->
            True

        "enabled" ->
            True

        _ ->
            False


renderContract : Mode -> VisualContract -> Html Msg
renderContract mode vc =
    div [ Styles.contract mode, Styles.contractContent mode (metaData vc "") ]
        [ renderHeader mode (metaData vc "")
        , renderContractContent mode vc
        ]


renderContractContent : Mode -> VisualContract -> Html Msg
renderContractContent mode vc =
    case vc of
        VStringValue s ->
            div [ Styles.stringValue mode ]
                [ text s ]

        VIntValue i ->
            div [ Styles.intValue mode ]
                [ text <| String.fromInt i ]

        VBoolValue i ->
            div [ Styles.boolValue mode ]
                [ text <| stringFromBool i ]

        VFloatValue f ->
            div [ Styles.floatValue mode ]
                [ text <| String.fromFloat f ]

        VFunction { argument, name, retval, data, pid } ->
            div [ Styles.function mode, title ("name: " ++ name ++ ", pid: " ++ String.fromInt pid) ]
                [ div [ Styles.functionArgumentType mode ]
                    [ text <| inspectType argument ]
                , div [ Styles.functionRetvalType mode ]
                    [ text <| inspectType retval ]
                , case argument of
                    TNil ->
                        case retval of
                            TNil ->
                                button [ Styles.actionCallButton mode, onClick (ActionCall vc) ] [ text "button" ]

                            _ ->
                                button [ Styles.instantCallButton mode, onClick (AskInstantCall vc) ] [ text "instant call" ]

                    _ ->
                        button [ Styles.functionCallButton mode, onClick (AskCall vc) ] [ text "call" ]
                , renderData mode data
                ]

        VConnectedDelegate { contract, data, destination } ->
            div [ Styles.connectedDelegate mode ]
                [ div [ Styles.delegateDescriptor mode, title ("destination: " ++ String.fromInt destination) ]
                    [ renderData mode data ]
                , div [ Styles.delegateSubContract mode ]
                    [ renderContract mode contract ]
                ]

        VBrokenDelegate { data, destination } ->
            div [ Styles.brokenDelegate mode ]
                [ div [ Styles.delegateDescriptor mode, title ("destination: " ++ String.fromInt destination) ]
                    [ renderData mode data ]
                ]

        VMapContract d ->
            div [ Styles.mapContract mode ]
                (Dict.toList d
                    |> List.map
                        (\( name, contract ) ->
                            div [ Styles.mapContractItem mode, Styles.contractContent mode (metaData contract name) ]
                                [ renderHeader mode (metaData contract name)
                                , div [ Styles.mapContractName mode ] [ text name ]
                                , renderContractContent mode contract
                                ]
                        )
                )

        VListContract l ->
            div [ Styles.listContract mode ]
                (l
                    |> List.map
                        (\contract ->
                            div [ Styles.listContractItem mode, Styles.contractContent mode (metaData contract "") ]
                                [ renderHeader mode (metaData contract "")
                                , renderContractContent mode contract
                                ]
                        )
                )

        VProperty { pid, propertyID, value, contract } ->
            div [ Styles.propertyBlock mode ]
                [ renderProperty mode pid propertyID value
                , div [ Styles.propertySubContract mode ] [ renderContractContent mode contract ]
                ]


renderHeader : Mode -> MetaData -> Html Msg
renderHeader mode { description, enabled } =
    div [ Styles.contractHeader mode enabled ]
        [ text description ]


renderData : Mode -> Data -> Html Msg
renderData mode d =
    div [ Styles.dataBlock mode ]
        (Dict.toList d
            |> List.filter
                (\( name, _ ) -> not <| isMeta name)
            |> List.map
                (\( name, value ) ->
                    div [ Styles.dataItem mode ]
                        [ div [ Styles.dataName mode ] [ text name ]
                        , div [ Styles.dataValue mode ] [ text (Json.Encode.encode 0 value) ]
                        ]
                )
        )


renderAskCallWindow : Mode -> Maybe VisualContract -> Maybe Json.Encode.Value -> Maybe String -> Maybe Json.Encode.Value -> Html Msg
renderAskCallWindow mode mf callArgument callToken callResult =
    case mf of
        Just (VFunction { argument, name, retval, data, pid }) ->
            div [ Styles.callWindow mode ]
                [ button [ onClick CancelCall, Styles.callCancel mode ] [ text "cancel" ]
                , div [ Styles.callFunctionName mode ] [ text name ]
                , div [ Styles.callFunctionArgumentType mode ] [ text <| inspectType argument ]
                , div [ Styles.callFunctionRetvalType mode ] [ text <| inspectType retval ]
                , case callArgument of
                    Nothing ->
                        div [ Styles.callFunctionEntry mode ]
                            [ input [ onInput CallArgumentInput ] []
                            ]

                    Just jsonArg ->
                        case callToken of
                            Nothing ->
                                div [ Styles.callFunctionEntry mode ]
                                    [ input [ onInput CallArgumentInput ] []
                                    , button
                                        [ onClick (PerformCall { target = delegate pid, name = name, argument = jsonArg })
                                        ]
                                        [ text "call" ]
                                    ]

                            Just _ ->
                                div []
                                    [ div [ Styles.callFunctionInput mode ] [ text <| Json.Encode.encode 0 jsonArg ]
                                    , case callResult of
                                        Nothing ->
                                            div [ Styles.callFunctionOutputWaiting mode ] []

                                        Just returned ->
                                            div [ Styles.callFunctionOutput mode ] [ text <| Json.Encode.encode 0 returned ]
                                    ]
                ]

        _ ->
            div [] []


renderProperty : Mode -> Pid -> PropertyID -> Property -> Html Msg
renderProperty mode pid propID prop =
    div [ Styles.propertyContainer mode ] <|
        justs
            [ renderPropertyControl mode pid propID prop
            , Maybe.map (renderValue mode (propValueStyle mode prop)) prop.value
            , renderPropertyGetButton mode pid propID prop
            ]


propValueStyle : Mode -> Property -> Attribute Msg
propValueStyle mode prop =
    case prop.setter of
        Nothing ->
            Styles.readOnlyValue mode

        Just _ ->
            Styles.propertyValue mode


renderValue : Mode -> Attribute Msg -> Value -> Html Msg
renderValue mode style value =
    (case value of
        SimpleInt i ->
            [ text (String.fromInt i) ]

        SimpleString s ->
            [ text s ]

        SimpleFloat f ->
            [ text (String.fromFloat f) ]

        SimpleBool True ->
            [ text "true" ]

        SimpleBool False ->
            [ text "false" ]

        Complex v ->
            [ text <| Json.Encode.encode 0 v ]

        Loading ->
            [ text "loading" ]
    )
        |> div [ style ]


renderPropertyGetButton : Mode -> Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyGetButton mode pid propID prop =
    case prop.getter of
        Nothing ->
            Nothing

        Just getter ->
            Just <|
                button
                    [ onClick (CallGetter ( pid, propID ) getter), Styles.propertyGet mode ]
                    [ text "↺" ]


renderPropertyControl : Mode -> Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyControl mode pid propID prop =
    case prop.setter of
        Nothing ->
            case prop.value of
                Just (SimpleFloat value) ->
                    case getMinMax prop of
                        Just minmax ->
                            Just <| renderFloatBarControl mode pid propID minmax value

                        Nothing ->
                            Nothing

                _ ->
                    Nothing

        Just setter ->
            case prop.value of
                Just (SimpleFloat value) ->
                    case getMinMax prop of
                        Just minmax ->
                            Just <| renderFloatSliderControl mode pid propID minmax setter value

                        Nothing ->
                            Nothing

                Just (SimpleBool value) ->
                    Just <| renderBoolCheckboxControl mode pid propID setter value

                _ ->
                    Nothing


renderFloatSliderControl : Mode -> Pid -> PropertyID -> ( Float, Float ) -> FunctionStruct -> Float -> Html Msg
renderFloatSliderControl mode pid propID ( min, max ) setter value =
    input
        [ Attrs.type_ "range"
        , Attrs.min (min |> String.fromFloat)
        , Attrs.max (max |> String.fromFloat)
        , Attrs.step "0.01" -- fixme!
        , Attrs.value <| String.fromFloat value
        , onInput
            (\s ->
                s
                    |> String.toFloat
                    |> Maybe.withDefault -1
                    |> Json.Encode.float
                    |> CallSetter ( pid, propID ) setter
            )
        , Styles.propertyFloatSlider
            mode
        ]
        []


renderFloatBarControl : Mode -> Pid -> PropertyID -> ( Float, Float ) -> Float -> Html Msg
renderFloatBarControl mode pid propID ( min, max ) value =
    let
        norm =
            (value - min) / (max - min)
    in
    div [ Styles.propertyFloatBar mode ]
        [ div [ Styles.progressBarOuter norm ]
            [ div [ Styles.progressBarInner norm ] []
            ]
        ]


renderBoolCheckboxControl : Mode -> Pid -> PropertyID -> FunctionStruct -> Bool -> Html Msg
renderBoolCheckboxControl mode pid propID setter value =
    Html.Styled.Keyed.node "span"
        []
        [ ( stringFromBool value, renderBoolCheckbox mode pid propID setter value )
        ]


renderBoolCheckbox : Mode -> Pid -> PropertyID -> FunctionStruct -> Bool -> Html Msg
renderBoolCheckbox mode pid propID setter value =
    input
        [ Attrs.type_ "checkbox"
        , Attrs.checked value
        , onClick (CallSetter ( pid, propID ) setter (Json.Encode.bool <| not value))
        , Styles.propertyBoolCheckbox
            mode
        ]
        []


justs : List (Maybe a) -> List a
justs l =
    case l of
        [] ->
            []

        (Just h) :: t ->
            h :: justs t

        Nothing :: t ->
            justs t


view : Model -> Document Msg
view model = Document
    "nice title"
    [ toUnstyled <| bodyView model ]

bodyView : Model -> Html Msg
bodyView model = case model.status of
    JollyGood ->
        let mode = case model.mode of
                Advanced -> "advanced"
                Basic    -> "basic"
        in
            div [ class ("mode-" ++ mode) ]
                [ renderContract model.mode <| toVisual 0 model.contracts model.allProperties
                , renderAskCallWindow model.mode model.toCall model.callArgument model.callToken model.callResult
                , Html.Styled.map UiMsg <| Html.Styled.fromUnstyled <| Ui.view model.ui
                ]
    Connecting ->
        div [] [ text "connecting" ]
    Reconnecting ->
        div [] [ text "reconnecting" ]


viewMessage : String -> Html msg
viewMessage msg =
    div [] [ text msg ]

stringFromBool : Bool -> String
stringFromBool b = case b of
    True -> "true"
    False -> "false"
