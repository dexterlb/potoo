module Styles exposing (..)

import Css exposing (..)
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled)

import Modes exposing (..)

contract mode = css
  [
  ]

contractContent mode { uiLevel } = case mode of
  Advanced -> css
    [
    ]
  Basic -> if uiLevel > 0
    then
      css
        [ display none
        ]
    else
      css
        [
        ]

mapContract = indentedContract
listContract = indentedContract

contractHeader mode enabled = css <| case mode of
  Basic ->
    case enabled of
      True  -> [ color (hex "cf0000") ]
      False -> [ color (hex "cccccc") ]
  Advanced ->
    [ display none ]

indentedContract mode = css
  [ marginLeft (px 20)
  ]

mapContractName mode = css <| case mode of
  Advanced ->
    [ display inline,
        after [ property "content" "\": \"" ]
    ]
  Basic -> [ display none ]

mapContractItem mode = css
  [
  ]

listContractItem mode = css
  [
  ]

function mode = css
  [ backgroundColor (hex "d3ead5")
  , display inline
  ]

functionArgumentType mode = css <| case mode of
  Advanced ->
    [ display inline,
        after [ property "content" "\" → \"", color (hex "c99376")]
    ]
  Basic ->
    [ display none
    ]

functionRetvalType mode = css <| case mode of
  Advanced ->
    [ display inline
    ]
  Basic ->
    [ display none
    ]

functionCallButton mode = css
  [
  ]

instantCallButton mode = css
  [
  ]

actionCallButton mode = css
  [
  ]

connectedDelegate mode = css
  [
  ]

brokenDelegate mode = css
  [
  ]

delegateDescriptor mode = css
  [
  ]

delegateSubContract mode = css
  [
  ]

intValue = simpleValue
boolValue = simpleValue
floatValue = simpleValue
stringValue = simpleValue

simpleValue mode = case mode of
  Advanced ->
    css [ display inline
    ]
  Basic -> indentedContract mode

dataBlock mode = css
  [ marginLeft (px 10),
    paddingLeft (px 10),
    borderLeft3 (px 1) solid (hex "000000")
  ]

dataItem mode = css
  [
  ]


dataName mode = css
  [ display inline
  , after [ property "content" "\": \"" ]
  ]

dataValue mode = css
  [ display inline
  ]

callWindow mode = css
  [
  ]

callFunctionName mode = css
  [
  ]

callFunctionArgumentType mode = css
  [
  ]

callFunctionRetvalType mode = css
  [
  ]

callFunctionEntry mode = css
  [
  ]

callFunctionInput mode = css
  [
  ]

callCancel mode = css
  [
  ]

callFunctionOutputWaiting mode = css
  [
  ]

callFunctionOutput mode = css
  [
  ]

propertyBlock mode = css
  [
  ]

propertySubContract mode = css <| case mode of
  Advanced ->
    [
    ]
  Basic ->
    [ display none
    ]

propertyGet mode = css <| case mode of
  Advanced ->
    [
    ]
  Basic ->
    [ display none
    ]

propertyContainer mode = css
  [ display inline
  ]

propertyValue mode = case mode of
  Advanced -> readOnlyPropertyValue mode
  Basic    -> css [display none]

readOnlyPropertyValue mode = css
  [ display inline
  , marginLeft (px 20)
  , before [ property "content" "\"► \"", color (hex "60f453") ]
  ]

propertyFloatBar mode = css
  [ display inline
  ]

propertyFloatSlider mode = css
  [ display inline
  ]

propertyBoolCheckbox mode = css
  [ display inline
  ]

progressBarOuter value = css
  [ display inlineBlock
  , position relative
  , marginLeft (px 15)
  , width (px 200)
  , height (px 10)
  , backgroundColor (hex "00cc00")
  ]

progressBarInner value = css
  [ display inlineBlock
  , position absolute
  , width <| px <| value * 200
  , height (px 10)
  , backgroundColor (hex "0000ff")
  ]
