module Styles exposing (..)

import Css exposing (..)
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled)

contract mode = css
  [
  ]

mapContract = indentedContract
listContract = indentedContract

indentedContract mode = css
  [ marginLeft (px 20)
  ]

mapContractName mode = css
  [ display inline,
    after [ property "content" "\": \"" ]
  ]

mapContractItem mode = css
  [
  ]

function mode = css
  [ backgroundColor (hex "d3ead5"),
    display inline
  ]

functionArgumentType mode = css
  [ display inline,
    after [ property "content" "\" → \"", color (hex "c99376")]
  ]

functionRetvalType mode = css
  [ display inline
  ]

functionCallButton mode = css
  [
  ]

instantCallButton mode = css
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
floatValue = simpleValue
stringValue = simpleValue

simpleValue mode = css
  [ display inline
  ]

dataBlock mode = css
  [ marginLeft (px 10),
    paddingLeft (px 10),
    borderLeft3 (px 1) solid (hex "000000")
  ]

dataItem mode = css
  [
  ]


dataName mode = css
  [ display inline,
    after [ property "content" "\": \"" ]
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

propertySubContract mode = css
  [
  ]

propertyGet mode = css
  [
  ]

propertyContainer mode = css
  [ display inline
  ]

propertyValue mode = css
  [ display inline
  , marginLeft (px 20)
  , before [ property "content" "\"► \"", color (hex "60f453") ]
  ]

propertyFloatSlider mode = css
  [ display inline
  ]

propertyBoolCheckbox mode = css
  [ display inline
  ]
