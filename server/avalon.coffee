#
# Server side game functions
#

Array::sum = () ->
    @reduce (x, y) -> x + y

send_game_list = () ->
    Game.find {}, (err, games) ->
        data = []
        for g in games
            if (g.state == GAME_LOBBY) then data.push
                id : g.id
                name : g.name()
                num_players : g.players.length
        io.sockets.in('lobby').emit('gamelist', data)

send_game_info = (game) ->
    data =
        state           : game.state
        id              : game.id
        roles           : game.roles
        currentLeader   : game.currentLeader
        currentMission  : game.currentMission
        missions        : game.missions

    #Overwrite player data (to hide secret info)
    #Split out socket ids while we're at it, no need to send them
    players = []
    socks = []
    for p in game.players
        socks.push(io.sockets.socket(p.socket))
        players.push
            id          : p.id
            name        : p.name
            ready       : p.ready

    data.players = players

    #Hide unfinished votes
    votes = []
    for v in game.votes
        dv = {mission: v.mission, team: v.team, votes: []}
        if v.votes.length == game.players.length
            dv.votes = v.votes
        votes.push dv

    data.votes = votes

    #Add in secret info specific to player as we go
    for s, i in socks
        data.players[i].role = game.players[i].role
        data.players[i].isEvil = game.players[i].isEvil
        data.players[i].info = game.players[i].info
        data.me = i
        s.emit('gameinfo', data)
        data.players[i].role = undefined
        data.players[i].isEvil = undefined
        data.players[i].info = []

leave_game = (socket, game_id) ->
    Game.findById game_id, (err, game) ->
        for p in game.players
            if p.socket == socket
                index = game.players.indexOf(p)
                game.players.splice(index, 1)
                break
        game.save()

        if game.players.length == 0
            game.remove()
        send_game_list()
        send_game_info(game)

shuffle = (a) ->
      for i in [a.length-1..1]
          j = Math.floor Math.random() * (i + 1)
          [a[i], a[j]] = [a[j], a[i]]
      return a

start_game = (game) ->
    game.state = GAME_PROPOSE

    #Temporary roles (no options yet)
    game.roles.push
        name    : "Merlin"
        isEvil  : false
    game.roles.push
        name    : "Assassin"
        isEvil  : true
    game.roles.push
        name    : "Percival"
        isEvil  : false
    game.roles.push
        name    : "Morgana"
        isEvil  : true
    cur_evil = 2

    #Fill evil
    num_evil = Math.ceil(game.players.length / 3)
    while (cur_evil < num_evil)
        game.roles.push
            name : "Minion"
            isEvil : true
        cur_evil += 1

    #Fill good
    while (game.roles.length < game.players.length)
        game.roles.push
            name : "Servant"
            isEvil : false

    #Assign roles
    playerroles = shuffle(game.roles)
    for p in game.players
        r = playerroles.pop()
        p.role = r.name
        p.isEvil = r.isEvil

    #Give info
    for p in game.players
        switch p.role
            when "Merlin", "Assassin", "Minion", "Morgana"
                for o in game.players
                    if o.isEvil
                        p.info.push
                            otherPlayer : o.name
                            information : "evil"
            when "Percival"
                for o in game.players
                    if o.role == "Merlin" || o.role == "Morgana"
                        p.info.push
                            otherPlayer : o.name
                            information : "magic"

    game.setup_missions()
    leader = Math.floor Math.random() * game.players.length
    game.currentLeader = game.players[leader].id

#
# Socket handling
#

io.on 'connection', (socket) ->
    socket.on 'newuser', (data) ->
        socket.set('name', data['name'])
        socket.join('lobby')
        send_game_list()

    socket.on 'newgame', (game) ->
        socket.get 'name', (err, name) ->
            game = new Game()
            id = game.add_player(name, socket.id)
            game.save (err, data) ->
                socket.leave('lobby')
                socket.set('game', game._id)
                socket.set('player_id', id)
                send_game_list()
                send_game_info(game)

    socket.on 'joingame', (data) ->
        game_id = data.game_id
        socket.get 'name', (err, name) ->
            Game.findById game_id, (err, game) ->
                id = game.add_player(name, socket.id)
                console.log "SETTING ID TO: " + id
                game.save (err, data) ->
                    socket.leave('lobby')
                    socket.set('game', game._id)
                    socket.set('player_id', id)
                    send_game_list()
                    send_game_info(game)

    socket.on 'ready', () ->
        socket.get 'game', (err, game_id) ->
            return if game_id == null
            Game.findById game_id, (err, game) ->
                all_ready = true
                for p in game.players
                    if p.socket == socket.id
                        p.ready = !p.ready
                    all_ready = false if !p.ready

                if game.players.length >= 5 && all_ready
                    start_game(game)

                game.save()
                send_game_info(game)

    socket.on 'propose_mission', (data) ->
        socket.get 'game', (err, game_id) ->
            return if game_id == null
            Game.findById game_id, (err, game) ->
                mission = game.missions[game.currentMission]
                return if data.length != mission.numReq
                game.votes.push
                    mission : game.currentMission
                    team    : data
                    votes   : []
                game.state = GAME_VOTE
                game.save()
                send_game_info(game)

    socket.on 'vote', (data) ->
        socket.get 'game', (err, game_id) ->
            return if game_id == undefined
            socket.get 'player_id', (err, player_id) ->
                return if player_id == undefined
                Game.findById game_id, (err, game) ->
                    currVote = game.votes[game.votes.length - 1]
                    currVote.votes.push
                        id      : player_id
                        vote    : data
                    if currVote.votes.length == game.players.length
                        vs = ((if v.vote then 1 else 0) for v in currVote.votes)
                        vs = vs.sum()
                        if vs > (game.players.length - vs)
                            game.state = GAME_QUEST
                        else
                            game.state = GAME_PROPOSE
                        game.set_next_leader()
                        game.save()
                        send_game_info(game)
                    else
                        game.save()

    socket.on 'quest', (data) ->
        socket.get 'game', (err, game_id) ->
            return if game_id == undefined
            socket.get 'player_id', (err, player_id) ->
                return if player_id == undefined
                Game.findById game_id, (err, game) ->
                    currVote = game.votes[game.votes.length - 1]
                    return if not (player_id in currVote.team)
                    currMission = game.missions[game.currentMission]
                    return if player_id in (p.id for p in currMission.players)
                    currMission.players.push
                        id          : player_id
                        success     : data

                    if currMission.players.length == currMission.numReq
                        #See if the mission succeeded or failed
                        fails = ((if p.success then 0 else 1) for p in currMission.players)
                        fails = fails.sum()
                        if fails >= currMission.failsReq
                            currMission.status = 1
                        else
                            currMission.status = 2

                        #Check if the game is over
                        succ = ((if m.status == 2 then 1 else 0) for m in game.missions)
                        succ = succ.sum()
                        fail = ((if m.status == 1 then 1 else 0) for m in game.missions)
                        fail = fail.sum()
                        if succ == 3 || fail == 3
                            game.state = GAME_FINISHED
                        else
                            game.currentMission += 1
                            game.state = GAME_PROPOSE

                        game.save()
                        send_game_info(game)
                    else
                        game.save()
  
    socket.on 'disconnect', () ->
        socket.get 'game', (err, game_id) ->
            return if not game_id
            Game.findById game_id, (err, game) ->
                if game.status == GAME_LOBBY
                    leave_game(socket.id, game_id)
