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
    "number_of_players": number between 2 and 6
}
```