package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"

	"github.com/dexterlb/junkpotoo/toys/mpv_controller/potoo"
	"github.com/dexterlb/mpvipc"
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
			"get": {
				"name": "volume.get",
				"data": {},
				"argument": null,
				"retval": ["type", "float", {"min": 0, "max": 100}],
				"__type__": "function"
			},
			"set": {
				"name": "volume.set",
				"data": {},
				"argument": ["type", "float", {"min": 0, "max": 100}],
				"retval": null,
				"__type__": "function"
			},
			"subscribe": {
				"name": "volume.subscribe",
				"data": {},
				"argument": null,
				"retval": ["channel", ["type", "float", {"min": 0, "max": 100}]],
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
	potooConn := potoo.NewConnection("localhost:4123")
	err := potooConn.Open()
	if err != nil {
		log.Fatalf("cannot open potoo connection: %s", err)
	}
	go func() {
		potooConn.WaitUntilClosed()
		log.Fatal("connection to potoo died")
	}()

	pidDelegate, err := potooConn.Call("my_pid")
	if err != nil {
		log.Fatalf("cannot get pid: %s", err)
	}
	pid := int(pidDelegate.(map[string]interface{})["destination"].(float64))
	log.Printf("pid: %d", pid)

	if len(os.Args) > 1 {
		args := append(os.Args[1:], "--input-ipc-server=/tmp/mpv")
		cmd := exec.Command("mpv", args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		go cmd.Run()
		defer cmd.Process.Kill()
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

	potooConn.SetHandler("controls.playpause", func(arg interface{}) interface{} {
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

	volumeChan, err := potooConn.Call("make_channel")
	if err != nil {
		log.Fatal("cannot make volume channel: %s", err)
	}

	potooConn.SetHandler("volume.get", func(arg interface{}) interface{} {
		if arg != nil {
			panic("argument given to volume.get")
		}

		data, err := mpvConn.Call("get_property", "volume")
		if err != nil {
			log.Fatal("unable to get volume: %s", err)
		}

		return data.(float64)
	})

	potooConn.SetHandler("volume.set", func(arg interface{}) interface{} {
		volume := arg.(float64)

		_, err := mpvConn.Call("set_property", "volume", volume)
		if err != nil {
			log.Fatal("unable to set volume: %s", err)
		}

		return nil
	})

	potooConn.SetHandler("volume.subscribe", func(arg interface{}) interface{} {
		if arg != nil {
			panic("argument given to volume.subscribe")
		}

		return volumeChan
	})

	err = potooConn.OkCall("set_contract", json.RawMessage(contract))
	if err != nil {
		log.Fatalf("cannot set contract: %s", err)
	}

	err = potooConn.OkCall("call", map[string]interface{}{
		"pid":  0,
		"path": "register",
		"argument": map[string]interface{}{
			"name": "epic_player",
			"delegate": &potoo.Delegate{
				Destination: pid,
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
			err := potooConn.OkCall("send_on", map[string]interface{}{
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
