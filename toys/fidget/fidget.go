package main

import "fmt"
import "github.com/DexterLB/potoo/go/potoo/types"

func main() {
    ser := types.MakeSerialiser(types.Type{T: types.TInt{}}, 500)
    foo := 70
    err := ser.DecodeString("null", &foo)
    if err != nil {
        fmt.Printf("error: %s\n", err)
    }
    fmt.Printf("foo: %d\n", foo)
}
