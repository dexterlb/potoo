package types

import (
	"fmt"
	"strings"

	"github.com/valyala/fastjson"
)

type MetaData map[string]*fastjson.Value

func (m MetaData) String() string {
	if m == nil || len(m) == 0 {
		return "<>"
	}
	items := make([]string, 0, len(m))
	for k := range m {
        items = append(items, fmt.Sprintf("%s: %s", k, m[k].String()))
	}

	return fmt.Sprintf("<%s>", strings.Join(items, ", "))
}

func (t Type) M(meta MetaData) Type {
    t.Meta = meta
    return t
}
