io = require('socket.io')
express = require('express')
app = express()
server = app.listen(PORT)

app.use express.static(__dirname + '/js')
app.use express.static(__dirname + '/css')
app.use express.static(__dirname + '/img')

app.get '/', (req, res) ->
    res.set('Pragma', 'no-cache')
    res.sendFile(__dirname + '/html/index.html')

app.get '/games', (req, res) ->
    res.sendFile(__dirname + '/html/games.html')

app.get '/game', (req, res) ->
    res.sendFile(__dirname + '/html/game.html')

app.get '/admin', (req, res) ->
    res.sendFile(__dirname + '/html/admin.html')

app.get '/api', (req, res) ->
    return if not req.query['type']
    switch req.query['type']
        when "games"
            req_state = req.query['gamestate']
            if not req_state
                req_state = GAME_FINISHED
            else
                req_state = parseInt(req_state)

            Game.find {}, (err, games) ->
                response = []
                for g in games
                    if g.state != req_state
                        continue

                    response.push
                        name : g.name()
                        date : g.created
                        id   : g._id

                res.send(response)
        when "game"
            Game.findById req.query['id'], (err, game) ->
                res.send(game)
        when "deletegame"
            Game.findByIdAndRemove req.query['id'], () ->
                console.log "removed"
            res.send("{success: true}")
        else
            res.send("{blah: 'blah'}")

io = io.listen server
io.set('transports', ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'])

parseCookies = (headers) ->
    cookies = {}
    if headers.cookie
        for c in headers.cookie.split("; ")
            s = c.split("=")
            if s.length == 2
                cookies[s[0]] = s[1]
    return cookies

io.use (socket, next) ->
    data = socket.handshake
    cookies = parseCookies(data.headers)
    if not cookies || not cookies['player_id']
        if data.query.player_id
            cookies = {player_id: data.query.player_id}

    data.headers.cookie = cookies
    next()
    return

if DEBUG
    io.set('log level', 0)
else
    io.set('log level', 0)
    io.enable('browser client minification')
