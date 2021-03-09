# DeliveryLocationService

## Overview

### Non-web
Location defines the data structure to work with drivers and their data

LocationServer is the GenServer that handles the drivers' state. Think of it as independent processes that hold state and execute operations on that state.

Locations is a module that is solely used to call the GenServer and ask it for data or manipulate it. This most likely shouldn't exist and we could add all of these functions in the GenServer module itself, rather than having another function to call the GenServer on our behalf.

LocationSupervisor is simply a Supervisor that checks that the LocationServer doesn't crash. This could be considered the entry-point to create a new supervised driver process.

We also have an ets table (in-memory database) that holds the drivers' processes' state in case they crash. Since we should be getting data constantly and previous data doesn't matter, we should be fine to eventually remove this altogether.

### Web
The web portion of the code contains the actual interactions. The business logic is sadly ingrained in the channels (they should be handled in the non-web part of the code), eventually a refactor is required, but this could be difficult since the web portion is sort of coupled with the business logic itself.

The general idea is that admins, restaurants and drivers are all connected. The drivers channel sends updates to the admin constantly and to the restaurant channel only when the restaurant is subscribed to a driver (e.g the driver is delivering for that restaurant).

## Testing
To run a testing server we need to set an API_URL variable (where the sockets will attempt to verify the users). To run the dev server with this variable use:
`MIX_ENV=test API_URL=yoururl.com mix phx.server`

To run an interactive shell we need Iex:
`MIX_ENV=test API_URL=yoururl.com iex -S mix phx.server`
