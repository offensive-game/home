# Setup

1. Clone this repo
2. Add executing permissions to `clone-repos.sh` script
3. Execute `clone-repos.sh` script. It will clone each repository under apps folder

## Add new application

1. Create a new repository under `offensive-game` organization on github
2. In `clone-repos.sh` script add name of the repository to `appNames` array
3. Update `docker-compose.yml` file to add new microservice

# Game specification

## Login / Signup

### Using username / password
User will have ability to create a new account. In order to do so he needs to enter email, username and password. So client will hit `/signup` http enpoint with `POST` request. Body of message will be:
```
{
    "email": "email@gmail.com",
    "username": "choosen user name",
    "password": "some password"
}
```
Response should contain the same fields and status code `200` if registration was successfull (or some other http error code in case of error),

After that user should be able to log in using the same credentials by hitting `login` endpoint. Message body should be:
```
{
    "username": "username",
    "password": "password"
}
```
In response server should return the same response (with appropriate status code) plus email address. Also, server should set cookie `offensive-login` with generated login token. Server will check that cookie on each subsequent message to determine if user is logged in

### Using Facebook
TODO... Facebook is using OAuth. I'm not completely sure how the process of login is going. This is something that I should re-check :) 

## Creating a new game
When creating a new game client will hit `/game` endpoint with `POST` request. Message body:
```
{
    "name": "Game name",
    "number_of_players": number between 2 and 6,
    "wait_time": 60
}
```

`wait_time` field represents number of seconds before the game starts. In case that it times out and still there are missing players their places will be filled up with bots. Response for this message will be in following format:
```
{
    "name": "Game name",
    "number_of_players": 3,
    "start_time": timestamp when the game starts,
    "game_id": unique identifier of game
}
```

## Getting the list of currently active games
The client will issue `GET` request to `/game` endpoint with no body. This is protected route so if user is not logged in, server should respond with status code `401`. Response for this request should be following:
```
{
    games: [
        {...game1},
        {...game2},
        {...game3}
    ]
}
```
Each of game objects (game1, game2, game3...) should be in the same format as create game response, described in upper chapter. For the first version I think that we don't need to implement paging for this request. NOTE: Client can occasionally can re-send this request in order to refresh list of currently active games.

## Joining the game
In order to join the game client will send `GET` request to `/game/gameId` endpoint. `gameId` param represents game identifier received in previous message. In the response server should return current status of the game (or appropriate HTTP status code if the user can't join the game). Example of message:
```
{
    "game_id": id of joined game,
    "start_time": timestamp,
    "name": Game 1,
    "number_of_players": 6,
    "color": Color assigned to current player,
    "player_id": id,
    "players: [
        { "id": "id", "name": "player name", "color": "color of this player" },
        { "id": "id", "name": "player name", "color": "color of this player" },
        ...
    ]
}
```
`players` array is list of all players that are joined to game so far. 
Immediately after receiving response for joining the game, client will open web-socket connection to server which will be used in cases when server wants to notify client about some change that was not triggered by current client. So after the current player is joined on each subsequential join of some other player to this game, server should send via web-socket to each client joined to game following message:
```
{
    "type": "OPPONENT_JOINED_SUCCESS",
    "payload": {
        "player_id": id,
        "color": color,
        "name": name
    }
}
```

After all players are joined to game server should send complete list of players to all clients. NOTE: in case that game should start and some players are still missing their places should be filled with bots, and those bots should participate in this list. For client it's totally transparent which player is bot and which is real player, it will treat them the same way.

```
{
    "type": "GAME_START_SUCCESS",
    "payload": {
    "game_id": id of joined game,
    "start_time": timestamp,
    "name": Game 1,
    "number_of_players": 6,
    "color": Color assigned to current player,
    "player_id": id,
    "players: [
        { "id": "id", "name": "player name", "color": "color of this player" },
        { "id": "id", "name": "player name", "color": "color of this player" },
        ...
    ]
}
}
```


