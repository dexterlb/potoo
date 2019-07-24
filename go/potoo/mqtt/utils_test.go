package mqtt

import (
	"strings"
	"testing"
)

func TestJoinTopics(t *testing.T) {
	jt := func(items ...string) {
		var topics []Topic
		for i := 0; i < len(items)-1; i++ {
			topics = append(topics, Topic(items[i]))
		}

		joined := string(JoinTopics(topics...))

		if joined != items[len(items)-1] {
			t.Errorf(
				"joining %s produced '%s' instead of '%s'",
				strings.Join(items[0:len(items)-1], ", "),
				joined,
				items[len(items)-1],
			)
		}
	}

	jt("foo", "bar", "foo/bar")
	jt("/foo/", "/bar/", "foo/bar")
	jt("/foo/bar//baz", "foo/bar/baz")
	jt("foo/bar", "baz", "foo/bar/baz")
	jt("foo//bar", "baz", "foo/bar/baz")
	jt("foo//bar/", "baz", "foo/bar/baz")
	jt("foo//bar/", "baz/", "foo/bar/baz")
	jt("foo//bar/", "baz/", "/", "foo/bar/baz")
}
