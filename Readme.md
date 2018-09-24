# Setup

1. Clone this repo
2. Add executing permissions to `clone-repos.sh` script
3. Execute `clone-repos.sh` script. It will clone each repository under apps folder
4. Add `127.0.0.1   offensive.local` to hosts file (`/etc/hosts`)
5. In the directory where `docker-compose.yml` file is stored open terminal and run `docker-compose up`
6. In the root folder there are development key and certificate. Make sure that you make that certificate trusted in OS
7. When running docker it might have problem with binding to port 443 since it's default HTTPS port. On Linux you just need to run docker with root permissions once.
8. Open browser and go to `https://offensive.local`

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

## Getting current user info
The client can fetch information about himself on `GET /me` endpoint. Response body should have all fields related to current player:
```
{
    "username": "username",
    "player_id": "player_id",
    ... for v2 we might have some additional fields related to player like number of games / number of wins / credits...
}
```

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
Immediately after receiving response for joining the game, client will open web-socket connection to server (`serveraddress/ws?token=user_login_token`) which will be used in cases when server wants to notify client about some change that was not triggered by current client. So after the current player is joined on each subsequential join of some other player to this game, server should send via web-socket to each client joined to game following message:
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

## Game execution
Game execution starts with sending game status message. This message will be used in several places and it contains whole board state for each user. It should have the following format:
```
{
    "game_id": identifier,
    "phase": "phase",
    "round": 1,
    "round_deadline": timestamp or null,
    "players": [
        {
            "id": player id,
            "name": player name,
            "color": player color,
            "lands": [
                {
                    "name": "argentina" // this can be id of territory becaouse it's unique
                    "number_of_units": 12
                }
            ],
            "cards": ["airforce", "artillery", "infantry", "jocker"],
            "units_in_reserve": 3
        }
    ]
}
```

`cards` and `units_in_reserve` fields are sent only for current user, for opponents those fields should not exist. This is slight improvement so that some playert can't open developer console and see which cards other players hold. Maybe it's not needed for V1?

### Game beginning
Each player will receive a message through WS in following format:
```
{
    "type": "GAME_START_SUCCESS",
    "payload": {
        ...game status message described above
    }
}
```
In this message territories will be randomly assigned to player with `0` units on each territory. Some time after that the first phase of game starts. Phases in game are `deployment`, `attack`, `wars` and `move`. The game starts with `advance phase` message. New phase is `deployment`. Each territory has 0 units on it and each player has initial amount of troops in reserve. Deadline is in 60 seconds after phase starts.
```
{
    "type": "PHASE_ADVANCE_SUCCESS",
    "payload": {
        ...game status
    }
}
```

### Deployment
To deploy unit client will hit `/deploy` endpoint with `POST` request in following format:
```
{
    "game_id": game id,
    "player_id": player id,
    "land": "argentina"
}
```
Each request will add one troop on selected territory. It's not possible to re-deploy unit after it's added to some land. Server will respond with the same message and appropriate REST status code.

### Attacking
As a previous phase this one starts with game status message from server to client through WS. Note that if some player did not deployed all troops they will be randomly assigned to territories (or leave them to reserve - this is a game design decision). Either way, `PHASE_ADVANCE_SUCCESS` message should contain whole correct status of game.

To make an attack client will hit `/attack` endpoint with `POST` request. Request body:
```
{
    "game_id": game id,
    "from_land": "argentina",
    "to_land": brazil,
    "number_of_units": 3
}
```
Response should be in the same format with appropriate status code. NOTE: here we should check some validations: those lands have common border, enough number of troops... Duration of this round is also 60 seconds (we can tweek this period), and after it we advance to next phase.

### Wars
This is the most complex phase. it also beginns with `PHASE_ADVANCE_SUCCESS` message through WS. Server needs to sort attacks in order and send one by one to client. Since this phase has variable duration depending on battles its `round_deadline` field should be `null`.

Each attack is divided to separate battles. Battle beggins with `BATTLE_EXECUTION_SUCCESS` message from server to client through WS in following format:
```
{
    "type": "BATTLE_EXECUTION_SUCCESS",
    "payload": {
        "battle_id": id,
        "attackers": [
            {
                "id": attacker id,
                "number_of_units": 2
            },
            ...
        ],
        "defender_id" player id of defender,
        "defender_units": number of units on defender's land
    }
}
```

Attackers will have 10 seconds to hit `POST` `/roll` endpoint with following body:
```
{
    "game_id": id,
    "player_id": id,
    "battle_id": id
}   
```
In response server will respond with the same message plus one more field `dices` which is and array of up to 3 numbers.

If attacker does not hit that endpoint within 10 seconds it will be considered that he retreated and this battle will be terminated leaving the same state of board as before battle.
If defender does not hit that endpoint within 10 seconds server will anyway throw dices for him.
After dices are thrown either way server will send next `BATTLE_EXECUTION_SUCCESS` message with updated state.

Attacker can retreat at any point by hitting `/retreat` endpoint with the same message as on `roll` endpoint. Response is the same as request body.
When one battle is finished server should send `BATTLE_DONE_SUCCESS` message having a new state on the board.
```
{
    "type": "BATTLE_DONE_SUCCESS",
    "payload": {
        ...game state
    }
}
```

NOTE: those WS messages should be sent to all active players so their clients can display battle execution. Also, if attacker has conquered territory in updated state he should receive a new card.

### Move
After all battles are executed next `PHASE_ADVANCE_SUCCESS` is sent through WS moving to `move` phase and setting a deadline in 60 seconds.
During this phase clients can hit `/move` enpoint with `POST` request with following body:
```
{
    "game_id": id,
    "from_land": "argentina",
    "to_land": "brazil",
    "number_of_units" 2
}
```
Response is the same.

## Next round
This completes one round. Next round is again `deploymet` and everything goes in circle until we have winner.

## Reinforcements
At any point if user has 3 matching cards he can hit `/reinforce` endpoint with `POST` request in following format:
```
{
    "game_id": id,
    "player_id": id,
    "cards": ["airforce", "artillery", "infantry"]
}
```
Server should do validation and respond with appropriate status code. If request is successsfull it should send a response in the same format plus additional field `units_in_reserve` with a number of newly acquired units. Client will be able to add those units in next `deployment` phase. NOTE: remember to update game state.

## Game ending
After some user is defeated (does not have any land under control) he will not be able to participate in game anymore. Still he will continue to receive messages through WS so he can continue to watch other players playing. At the moment when he looses the last land all players should receive throught WS following message:
```
{
    "type": "PLAYER_DEFETED_SUCCESS",
    "payload": {
        "player_id" id
    }
}
```

When there is only one player left after it sends the last `PLAYER_DEFETED_SUCESS` message client will show the winner message. Server can close all WS connections and do a clean-up. Game has ended.
