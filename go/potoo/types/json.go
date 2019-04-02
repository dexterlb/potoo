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

    switch typ := pType.T.(type) {
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
	case TFloat:
	    if goType2 != reflect2.TypeOf(42.0) {
	        panic(fmt.Sprintf("trying to decode %s as float", goType2))
	    }
		return func(dec *gojay.Decoder, v Fuck) error {
			checkType(goPtr, v)
            var pb *float64
			err := dec.FloatNull(&pb)
			if err != nil {
				return err
			}
			if pb == nil {
			    return fmt.Errorf("got null instead of float")
			}
			goType2.Set(v, pb)
			return nil
		}
	case TString:
	    if goType2 != reflect2.TypeOf("foo") {
	        panic(fmt.Sprintf("trying to decode %s as string", goType2))
	    }
		return func(dec *gojay.Decoder, v Fuck) error {
			checkType(goPtr, v)
            var pb *string
			err := dec.StringNull(&pb)
			if err != nil {
				return err
			}
			if pb == nil {
			    return fmt.Errorf("got null instead of string")
			}
			goType2.Set(v, pb)
			return nil
		}
	case TMap:

        keySer := MakeSerialiser(typ.Key)
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

/*
    Here begins a rant.

    Fuck this lack of generics. Why do I have to write the same motherfucking
    thing 10 times and to what end? To get underperforming code because the
    stupid reflect package is slow and there's no way to extract a pointer from
    a bloody interface which IS a fucking pointer! Not only that, but even trying
    to mitigate the reflect performance hit by precomputing as much as possible
    and then capturing it in a closure doesn't work because guess what? The
    damn closures are fucking slow as hell.
    Use a fucking dynamically-typed language, you say: yeah, throw ALL possible
    compiler guarantees out of the window and shoot yourself in the leg.
    You know what that leaves us with? C++ (just no), rust (anyone who is not
    wearing a lumberjack shirt will refuse to use this code) and Haskell.
    So if I want this code to be usable by non-haskellists, I'm left with this
    mediocre language which, albeit mediocre, turns out to be better than all
    the rest for this task.
    Everything sucks and I want to kill myself.

    End of rant.
*/

