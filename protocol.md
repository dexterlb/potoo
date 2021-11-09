# Potoo 2

Potoo is a protocol for interface definition over MQTT. MQTT is a simple
message-passing protocol, while potoo describes how to create services which
can be queried for the functionality they provide.

This allows for building dynamic UIs, RPC with format validation and
automated discovery of services.

## Terminology

- *client*: an application/device/potato connected to the MQTT broker via one session
- *service*: a client who has published its contract in a designated retained topic
- *service root*: each service is associated with a *service root* which is simply a topic prefix
- *contract*: an object which describes all things a service can do

## Topic formats
- contract topic: `_contract/<service_root>`
- reply topic: `_reply/<reply_topic>`
- value topic: `_value/<service_root>/<path>`
- call topic: `_call/<service_root>/<path>`

## Client operation

- connecting as a simple client: simply connect to the broker. also generate a
  random string to serve as a reply topic for this client and subscribe
  to it.
- connecting as a service: designate a service root, connect with a
  LWT which publishes `null` to your contract topic and publish a contract
  at your contract topic (with retain).
- updating your contract: simply publish the new contract with retain
- updating a value (as a service): publish to the value topic with the new
  value (with retain)
- getting a value: subscribe to its topic. wait for it to arrive.
- performing a call: caller publishes to the call topic a message with
  format `{"topic": <reply_topic>, "token": <reply token>, argument: <argument>}`.
  Upon receiving it, the service verifies its type, performs the procedure
  and publishes a message `{"token": <reply token>, "result": <result>}` to the
  reply topic.

## Contract format

### Contract fields
A contract is just a JSON document with a recursive stucture - a contract is one
of the following:

| Contract           | JSON                              |
| ------------------ | --------------------------------- |
| constant           | `{ "_t": "constant", "value": <any JSON value> }` |
| value              | `{ "_t": "value", "type": <hoshi schema>, "subcontract": <contract> }` |
| callable           | `{ "_t": "callable", "argument": <hoshi schema>, "retval": <hoshi schema>, "subcontract": <contract> }` |
| map                | a map without a `"_t"` key whose values are contracts |

Each contract node is associated with a topic, which is composed of the map
keys in the path from root to it, delimited by slashes.

The description for "hoshi schema" may be seen in the
[hoshi readme](https://github.com/dexterlb/hoshi)

## API documentation

See the readmes in the respective language directories.
