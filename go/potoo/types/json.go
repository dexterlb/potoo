package types

import (
	"fmt"
	"io"
	"reflect"
	"strings"

	"github.com/francoispqt/gojay"
	"github.com/modern-go/reflect2"
)

type Serialiser struct {
	decoder decoder
}

func MakeSerialiser(pType Type, sampleValue Fuck) *Serialiser {
	return &Serialiser{
		decoder: makeDecoder(pType, sampleValue),
	}
}

func (s *Serialiser) Decode(r io.Reader, into Fuck) error {
	dec := gojay.BorrowDecoder(r)
	defer dec.Release()

	return s.decoder(dec, into)
}

func (s *Serialiser) DecodeString(str string, into Fuck) error {
	return s.Decode(strings.NewReader(str), into)
}

type decoder func(*gojay.Decoder, Fuck) error

func makeDecoder(pType Type, sampleValue Fuck) decoder {
	goType2 := reflect2.TypeOf(sampleValue)
    goPtr   := reflect2.PtrTo(goType2)
	goType := reflect.TypeOf(sampleValue)

	switch pType.T.(type) {
	case TVoid:
		return func(dec *gojay.Decoder, v Fuck) error {
			return fmt.Errorf("trying to decode Void, which is uninhabitable")
		}
	case TNull:
		if !nullable(goType) {
			panic(fmt.Sprintf("type is not nullable: %s", goType))
		}
		return func(dec *gojay.Decoder, v Fuck) error {
			checkType(goPtr, v)
			foo := 42
			ptr := &foo
			err := dec.IntNull(&ptr)
			if err != nil {
				return fmt.Errorf("cannot decode null: %s", err)
			}
			if ptr == nil {
				goType2.Set(v, nil)
				return nil
			} else {
				return fmt.Errorf("value not null: %d", foo)
			}
		}
	case TBool:
	    if goType2 != reflect2.TypeOf(false) {
	        panic(fmt.Sprintf("trying to decode %s as bool", goType2))
	    }
		return func(dec *gojay.Decoder, v Fuck) error {
			checkType(goPtr, v)
			b := false
			err := dec.Bool(&b)
			if err != nil {
				return err
			}
			goType2.Set(v, b)
			return nil
		}
	case TInt:
	    if goType2 != reflect2.TypeOf(42) {
	        panic(fmt.Sprintf("trying to decode %s as int", goType2))
	    }
		return func(dec *gojay.Decoder, v Fuck) error {
			checkType(goPtr, v)
            var pb *int
			err := dec.IntNull(&pb)
			if err != nil {
				return err
			}
			if pb == nil {
			    return fmt.Errorf("got null instead of int")
			}
			goType2.Set(v, pb)
			return nil
		}
	default:
		panic(fmt.Sprintf("don't know how to decode %s", pType))
	}
}

func nullable(t reflect.Type) bool {
	return t.Kind() == reflect.Ptr ||
		t.Kind() == reflect.Slice ||
		t.Kind() == reflect.Chan ||
		t.Kind() == reflect.Interface
}

func checkType(t reflect2.Type, v Fuck) {
	if t != reflect2.TypeOf(v) {
		panic(fmt.Sprintf("decoder for %s used on %s", t, reflect2.TypeOf(v)))
	}
}
