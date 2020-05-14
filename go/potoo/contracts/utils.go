package contracts

import (
	"github.com/DexterLB/potoo/go/potoo/mqtt"
)

func Traverse(c Contract, f func(Contract, mqtt.Topic)) {
	traverseHelper(c, f, mqtt.Topic{})
}

func traverseHelper(c Contract, f func(Contract, mqtt.Topic), topic mqtt.Topic) {
	if c == nil {
		return
	}

	f(c, topic)

	switch s := c.(type) {
	case Value:
		traverseHelper(s.Subcontract, f, topic)
	case Callable:
		traverseHelper(s.Subcontract, f, topic)
	case Constant:
		traverseHelper(s.Subcontract, f, topic)
	case Map:
		for key, sub := range s {
			traverseHelper(sub, f, mqtt.JoinTopics(topic, mqtt.Topic(key)))
		}
	}
}
