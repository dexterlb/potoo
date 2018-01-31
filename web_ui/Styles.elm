module Styles exposing (..)

import Css exposing (..)
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled)

contract = css
  [
  ]

mapContract = indentedContract
listContract = indentedContract

indentedContract = css
  [ marginLeft (px 20)
  ]

mapContractName = css
  [ display inline,
    after [ property "content" "\": \"" ]
  ]

mapContractItem = css
  [
  ]

function = css
  [ backgroundColor (hex "d3ead5"),
    display inline
  ]

functionArgumentType = css
  [ display inline,
    after [ property "content" "\" → \"", color (hex "c99376")]
  ]

functionRetvalType = css
  [ display inline
  ]

functionCallButton = css
  [
  ]

instantCallButton = css
  [
  ]

connectedDelegate = css
  [
  ]

brokenDelegate = css
  [
  ]

delegateDescriptor = css
  [
  ]

delegateSubContract = css
  [
  ]

intValue = simpleValue
floatValue = simpleValue
stringValue = simpleValue

simpleValue = css
  [ display inline
  ]

dataBlock = css
  [ marginLeft (px 10),
    paddingLeft (px 10),
    borderLeft3 (px 1) solid (hex "000000")
  ]

dataItem = css
  [
  ]


dataName = css
  [ display inline,
    after [ property "content" "\": \"" ]
  ]

dataValue = css
  [ display inline
  ]

callWindow = css
  [
  ]

callFunctionName = css
  [
  ]

callFunctionArgumentType = css
  [
  ]

callFunctionRetvalType = css
  [
  ]

callFunctionEntry = css
  [
  ]

callFunctionInput = css
  [
  ]

callCancel = css
  [
  ]

callFunctionOutputWaiting = css
  [
  ]

callFunctionOutput = css
  [
  ]

propertyBlock = css
  [
  ]

propertySubContract = css
  [
  ]

propertyGet = css
  [
  ]

propertyValue = css
  [
  ]

propertyFloatSlider = css
  [
  ]