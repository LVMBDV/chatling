# Chatling

Chatling is a barebones messaging app over TCP/IP.

## Usage

First, install the dependencies:

```
bundle install
```

To launch the server, run:

```
bin/chatling server localhost 3333
```

To launch a client, run:

```
bin/chatling client localhost 3333
```

If the connection is successful, you will see your identity that you can use to receive messages.

There are two commands that can be used to interract with the server:

```
/tell localhost:2323 Hello fren.
```

Sends a message to the specified user. The message is persistently stored on the
server so the recipient does not need to be online at the moment of sending.

```
/query contains:fren limit:10
```

Queries the server's message store using three filters:

- `contains:<word>` Only search for messages containing a word (case-sensitive).
- `limit:<number>` Limit the number of messages returned.
- `direction:<inbound|outbound>` Filter messages by direction.

## Development

You can run the functional tests in `/test` using:

```
rake test
```
