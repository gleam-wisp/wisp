import gleam/erlang/process
import gleam/list
import gleam/otp/actor

// We need to define the event messages that our chatroom needs to be able to
// handle.
pub type Event {
  // When a new client connects, we need to know its username as well as its
  // subject we can send messages to.
  Connected(username: String, connection: process.Subject(String))
  // When a client sends a message, we want the username of the client and the
  // message they sent.
  Message(username: String, message: String)
  // When a client disconnects, we need to know their username to remove their
  // subject from the client list.
  Disconnected(username: String)
  // If we want to cleanly shutdown the chat server from elsewhere in our
  // application.
  Shutdown
}

// This will store the clients details such as their username and their subject
// and any additional information required.
type Client {
  Client(username: String, connection: process.Subject(String))
}

// This holds the state of the chatroom server itself, with a list of all
// clients as well as all messages sent.
type State {
  State(clients: List(Client), messages: List(String))
}

// We create a start function to begin the chatroom server actor with a default
// state configuration.
pub fn start() -> Result(process.Subject(Event), actor.StartError) {
  let state = State(clients: [], messages: [])
  actor.start(state, handler)
}

// We then create a handler loop to handle the events defined above centrally
// for all of our client.
fn handler(event: Event, state: State) -> actor.Next(Event, State) {
  case event {
    // When a client connects, we add their details into the state
    //
    // As an exercise for the reader, you may wish to send back all the chat
    // history to the newly connected client!
    Connected(username, connection) -> {
      let clients = [Client(username, connection), ..state.clients]
      let state = State(..state, clients: clients)
      actor.continue(state)
    }
    // When a client sends a message, we prefix it with their username and then
    // forward that message to all clients in our states list of clients.
    //
    // We also add the message to our message history.
    Message(username, message) -> {
      let msg = username <> ": " <> message
      state.clients
      |> list.map(fn(client) { process.send(client.connection, msg) })
      let messages = [msg, ..state.messages]
      let state = State(..state, messages: messages)
      actor.continue(state)
    }
    // When a client disconnects, we remove it from our list so we no longer
    // forward any new messages to it.
    Disconnected(username) -> {
      let clients =
        state.clients |> list.filter(fn(client) { client.username != username })
      let state = State(..state, clients: clients)
      actor.continue(state)
    }
    // Finally we can shutdown if required. Typically you may clean up here, by
    // for example, notifying all clients the server is going down.
    Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}
