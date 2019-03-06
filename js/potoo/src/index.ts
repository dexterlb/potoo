import {Contract} from './contracts';
import * as mqtt from './mqtt';
export * from './mqtt';

export function foo() : string {
    return 'this is the foo';
}

export class Connection {
    constructor(private mqtt_client: mqtt.Client, private root: string) {
    }

    private root_topic: string

    async connect() : Promise<void> {
        await this.mqtt_client.connect({
            on_disconnect: this.on_disconnect,
            on_message:    this.on_message,
            will_message:  this.publish_contract_message(null),
        })
        console.log('connect')
    }

    private on_disconnect() {
        console.log('disconnect')
    }

    private on_message(message: mqtt.Message) {
        console.log('message: ', message)
    }

    private publish_contract(contract: Contract) {
        this.mqtt_client.publish(this.publish_contract_message(contract))
    }

    private publish_contract_message(contract: Contract): mqtt.Message {
        return {
            topic:   "_contract/${this.root}",
            retain:  true,
            payload: JSON.stringify(contract)
        }
    }
}
