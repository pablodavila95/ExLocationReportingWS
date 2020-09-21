//TODO convert to a Angular service
//TODO create separate implementations for each client
//TODO add the ws_url to the constructor
import { Socket, Presence } from "phoenix";
//This does not distinguish from a bad initial connection or a bad login (as in an auth error)

const env = { ws_url: "ws://127.0.0.1/socket/", ws_user: "driver" };
const messages_to_listen = [
  [
    "update_location",
    (data) => {
      console.log(data);
    },
  ],
  [
    "whatever",
    (data) => {
      console.log(data);
    },
  ],
  [
    //USERS/DRIVERS must have this to report presence to the admin
    "presence_diff", (diff) => {this.channel.push("presence_diff", diff)}
  ]
];

class SocketSession {
  hasConnected: boolean;
  token: string;
  socket: Socket;
  channel: any;
  //for admin
  presences: any;

  constructor(token: string, user_id: string) {
    this.hasConnected = false;
    this.token = token;
    this.socket = new Socket(env.ws_url + env.ws_user, {
      params: () => this.params(),
    });
    this.channel = this.socket.channel(env.ws_user + ":" + user_id, {
      params: { user_id: user_id },
    });
    this.presences = {};

    messages_to_listen.forEach((message_and_function) =>
      this.channel.on(message_and_function[0], message_and_function[1])
    );
    //for admin
    //dobule check the state and diff types
    this.channel.on("presence_state", (state: JSON) => {
      this.presences = Presence.syncState(this.presences, state);
    });
    this.channel.on("presence_diff", (diff: JSON) => {
      this.presences = Presence.syncDiff(this.presences, diff);
    });

    this.socket.onOpen(() => (this.hasConnected = true));
    this.socket.onError(() => {
      if (!this.hasConnected) {
        this.disconnect();
      }
    });
  }

  login(token: string) {
    this.token = token;
    this.socket.connect();
  }

  join() {
    this.channel.join();
  }

  send(message: string, data: JSON) {
    this.channel.push(message, data);
  }

  send_with_timeout(message: string, data: JSON, timeout: number) {
    this.channel.push(message, data, timeout);
  }

  params() {
    return { token };
  }

  disconnect() {
    this.socket.disconnect();
    //this.displayUILoginError()
  }
}
