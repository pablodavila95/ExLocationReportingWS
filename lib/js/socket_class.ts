import { Socket } from "phoenix";
//This does not distinguish from a bad initial connection or a bad login (as in an auth error)

const env = { ws_url: "ws://127.0.0.1/socket/", ws_user: "driver" };
const messages_to_listen = [
  [
    "update_location",
    () => {
      console.log();
    },
  ],
  [
    "whatever",
    () => {
      console.log();
    },
  ],
];

class SocketSession {
  hasConnected: boolean;
  token: string;
  socket: Socket;
  channel: any;

  constructor(token: string, user_id: string) {
    this.hasConnected = false;
    this.token = token;
    this.socket = new Socket(env.ws_url + env.ws_user, {
      params: () => this.params(),
    });
    this.channel = this.socket.channel(env.ws_user + ":" + user_id, {
      params: { user_id: user_id },
    });
    //Maybe change map to foreach?
    messages_to_listen.map((message_and_function) =>
      this.channel.on(message_and_function[0], message_and_function[1])
    );

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
    this.channel.push(message, data)
  }

  send_with_timeout(message: string, data: JSON, timeout: number) {
    this.channel.push(message, data, timeout)
  }

  params() {
    return { token };
  }

  disconnect() {
    this.socket.disconnect();
    //this.displayUILoginError()
  }
}
