package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"

	"github.com/DexterLB/junkmesh/toys/mpv_controller/mesh"
	"github.com/DexterLB/mpvipc"
)

const contract = `
{
	"description": "Video player",
	"controls": {
		"playpause": {
            "retval": null,
            "name": "controls.playpause",
            "data": {},
            "argument": null,
            "__type__": "function"
        }
	}
}
`

func main() {
	meshConn := mesh.NewConnection("localhost:4444")
	err := meshConn.Open()
	if err != nil {
		log.Fatalf("cannot open mesh connection: %s", err)
	}
	pid, err := meshConn.Call("my_pid")
	if err != nil {
		log.Fatalf("cannot get pid: %s", err)
	}
	log.Printf("pid: %v", pid)

	err = meshConn.OkCall("set_contract", json.RawMessage(contract))
	if err != nil {
		log.Fatalf("cannot set contract: %s", err)
	}

	err = meshConn.OkCall("call", map[string]interface{}{
		"pid":  0,
		"path": "register",
		"argument": map[string]interface{}{
			"name": "epic_player",
			"delegate": &mesh.Delegate{
				Destination: int(pid.(float64)),
				Data: map[string]interface{}{
					"description": "TV in my room",
				},
			},
		},
	})
	if err != nil {
		log.Fatalf("cannot register: %s", err)
	}

	if len(os.Args) > 1 {
		args := append(os.Args[1:], "--input-ipc-server=/tmp/mpv")
		cmd := exec.Command("mpv", args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		go cmd.Run()
		time.Sleep(2 * time.Second)
	}

	mpvConn := mpvipc.NewConnection("/tmp/mpv")
	err = mpvConn.Open()
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
