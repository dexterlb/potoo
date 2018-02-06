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
		},
		"volume": {
			"min_value": 0,
			"max_value": 100,
			"get": {
				"name": "volume.get",
				"data": {},
				"argument": null,
				"retval": "float",
				"__type__": "function"
			},
			"set": {
				"name": "volume.set",
				"data": {},
				"argument": "float",
				"retval": null,
				"__type__": "function"
			},
			"subscribe": {
				"name": "volume.subscribe",
				"data": {},
				"argument": null,
				"retval": ["channel", "float"],
				"__type__": "function"
			}
		}
	}
}
`

const (
	VOLUME_ID = 1
)

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

	meshConn.SetHandler("controls.playpause", func(arg interface{}) interface{} {
		if arg != nil {
			panic("argument given to playpause")
		}
		_, err := mpvConn.Call("cycle", "pause")
		if err != nil {
			log.Printf("cannot playpause: %s", err)
		}

		return nil
	})

	_, err = mpvConn.Call("observe_property", VOLUME_ID, "volume")
	if err != nil {
		fmt.Print(err)
	}

	volumeChan, err := meshConn.Call("make_channel")
	if err != nil {
		log.Fatal("cannot make volume channel: %s", err)
	}

	meshConn.SetHandler("volume.get", func(arg interface{}) interface{} {
		if arg != nil {
			panic("argument given to volume.get")
		}

		data, err := mpvConn.Call("get_property", "volume")
		if err != nil {
			log.Fatal("unable to get volume: %s", err)
		}

		return data.(float64)
	})

	meshConn.SetHandler("volume.set", func(arg interface{}) interface{} {
		volume := arg.(float64)

		_, err := mpvConn.Call("set_property", "volume", volume)
		if err != nil {
			log.Fatal("unable to set volume: %s", err)
		}

		return nil
	})

	meshConn.SetHandler("volume.subscribe", func(arg interface{}) interface{} {
		if arg != nil {
			panic("argument given to volume.subscribe")
		}

		return volumeChan
	})

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

	for event := range events {
		if event.ID == VOLUME_ID {
			volume := event.Data.(float64)
			log.Printf("volume now is %f", volume)
			err := meshConn.OkCall("send_on", map[string]interface{}{
				"channel": volumeChan,
				"message": volume,
			})

			if err != nil {
				log.Fatal("cannot send volume: %s", err)
			}
		} else {
			log.Printf("received event: %s", event.Name)
		}
	}
}
