package mqtt

func JoinTopics(topics ...Topic) Topic {
	var b []byte

	var lastc byte
	for i := range topics {
		var j int
		for ; j < len(topics[i]) && topics[i][j] == byte('/'); j++ {
		}
		for ; j < len(topics[i]); j++ {
			if topics[i][j] != byte('/') || lastc != byte('/') {
				lastc = topics[i][j]
				b = append(b, lastc)
			}
		}
		if lastc != byte('/') {
			b = append(b, byte('/'))
		}
	}

	if len(b) == 0 {
		return b
	}

	return Topic(b[:len(b)-1])
}
