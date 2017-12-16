package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"

	"github.com/DexterLB/mpvipc"
)

func main() {
	if len(os.Args) > 1 {
		args := append(os.Args[1:], "--input-ipc-server=/tmp/mpv")
		cmd := exec.Command("mpv", args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		go cmd.Run()
		time.Sleep(1 * time.Second)
	}

	mpvConn := mpvipc.NewConnection("/tmp/mpv")
	err := mpvConn.Open()
	if err != nil {
		log.Fatalf("cannot open connection: %s", err)
	}
	defer mpvConn.Close()

	events, stop := mpvConn.NewEventListener()

	go func() {
		mpvConn.WaitUntilClosed()
		stop <- struct{}{}
	}()

	_, err = mpvConn.Call("observe_property", 42, "volume")
	if err != nil {
		fmt.Print(err)
	}

	listenMpvEvents(events)
}

func listenMpvEvents(events chan *mpvipc.Event) {
	for event := range events {
		if event.ID == 42 {
			log.Printf("volume now is %f", event.Data.(float64))
		} else {
			log.Printf("received event: %s", event.Name)
		}
	}
}
