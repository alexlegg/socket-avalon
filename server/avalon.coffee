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

send_game_info = (game, to = undefined) ->
    data =
        state           : game.state
        options         : game.gameOptions
        id              : game.id
        roles           : game.roles
        currentLeader   : game.currentLeader
        finalLeader     : game.finalLeader
        currentMission  : game.currentMission
        missions        : game.missions

    #Overwrite player data (to hide secret info)
    #Split out socket ids while we're at it, no need to send them
    players = []
    socks = []
    for p, i in game.players
        if to == undefined || p.id.equals(to)
            socks.push
                socket  : io.sockets.socket(p.socket)
                player  : i
        players.push
            id          : p.id
            name        : p.name
            order       : p.order

    data.players = players

    #Hide unfinished votes
    votes = []
    for v in game.votes
        dv = {mission: v.mission, team: v.team, votes: []}
        if v.votes.length == game.players.length
            dv.votes = v.votes
        else
            dv.votes = []
            for pv in v.votes
                dv.votes.push {id: pv.id}
        votes.push dv

    data.votes = votes

    #Hide individual quest cards
    missions = []
    for m in game.missions
        numfails = 0
        for p in m.players
            if !p.success then numfails += 1
        dm = {numReq:m.numReq, failsReq: m.failsReq, status: m.status, numfails: numfails}
        missions.push dm

    data.missions = missions

    if game.state == GAME_FINISHED
        data.evilWon = game.evilWon
        if game.assassinated
            data.assassinated = undefined
            for p in game.players
                if p.id.equals(game.assassinated)
                    data.assassinated = p.name

    #Add in secret info specific to player as we go
    for s in socks
        i = s.player
        data.players[i].role = game.players[i].role
        data.players[i].isEvil = game.players[i].isEvil
        data.players[i].info = game.players[i].info
        data.me = data.players[i]
        s.socket.emit('gameinfo', data)
        data.players[i].role = undefined
        data.players[i].isEvil = undefined
        data.players[i].info = []

#
# Socket handling
#

io.on 'connection', (socket) ->
    cookies = socket.handshake.headers.cookie
    player_id = cookies['player_id']
    if not player_id
        socket.emit('bad_login')
    else
        Player.findById player_id, (err, player) ->
            if err || not player
                socket.emit('bad_login')
                return

            player.socket = socket.id
            player.save()
            socket.set('player', player)

            if not player.currentGame
                socket.join('lobby')
                send_game_list()
                return
            
            #Reconnect to game
            Game.findById player.currentGame, (err, game) ->
                if err || not game
                    socket.join('lobby')
                    send_game_list()
                    return

                for p in game.players
                    if p.id.equals(player_id)
                        if p.left
                            socket.emit('previous_game', game._id)
                            socket.join('lobby')
                            send_game_list()
                        else
                            p.socket = socket.id
                            game.save (err, game) ->
                                send_game_info(game, player_id)
                        return

                #Not in your current game
                socket.join('lobby')
                send_game_list()

    socket.on 'login', (data) ->
        socket.get 'player', (err, player) ->
            if err || not player
                player = new Player()
                player.name = data['name']
                player.socket = socket.id
                player.save()
                socket.set('player', player)
                socket.emit('player_id', player._id)
                socket.join('lobby')
                send_game_list()
            else
                player.name = data['name']
                player.save()

    socket.on 'newgame', (game) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            game = new Game()
            game.add_player player
            game.save (err, game) ->
                socket.leave('lobby')
                player.currentGame = game._id
                player.save()
                send_game_list()
                send_game_info(game)

    socket.on 'joingame', (data) ->
        game_id = data.game_id
        socket.get 'player', (err, player) ->
            return if err || not player
            if player.currentGame
                player.leave_game (err, game) ->
                    if game then send_game_info(game)
                    send_game_list()

            Game.findById game_id, (err, game) ->
                return if not game
                game.add_player player
                #TODO check if player was actually added
                game.save (err, game) ->
                    socket.leave('lobby')
                    player.currentGame = game._id
                    player.save()
                    send_game_list()
                    send_game_info(game)

    socket.on 'reconnecttogame', () ->
        socket.get 'player', (err, player) ->
            return if err || not player_id
            Game.findById player.currentGame, (err, game) ->
                return if not game
                socket.leave('lobby')
                for p in game.players
                    if p.id.equals(player_id)
                        p.socket = socket.id
                        p.left = false
                game.save (err, game) ->
                    send_game_info(game, player_id)

    socket.on 'ready', () ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                if game.players[0].socket == socket.id
                    if game.players.length >= 5
                        game.state = GAME_PREGAME

                game.save()
                send_game_info(game)

    socket.on 'kick', (player_id) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                if game.players[0].socket == socket.id
                    Player.findById player_id, (err, target) ->
                        return if err || not target
                        target.leave_game (err, game) ->
                            if game then send_game_info(game)
                            s = io.sockets.socket(target.socket)
                            s.emit('kicked')
                            s.join('lobby')
                            send_game_list()

    socket.on 'startgame', (data) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                order = data['order']
                game.gameOptions.mordred = data['options']['mordred']
                game.gameOptions.oberon = data['options']['oberon']
                game.gameOptions.showfails = data['options']['showfails']

                #Sanity check
                return if Object.keys(order).length + 1 != game.players.length

                game.start_game(order)
                game.save()
                send_game_info(game)

    socket.on 'propose_mission', (data) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
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
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                currVote = game.votes[game.votes.length - 1]

                #Check to prevent double voting
                for p in currVote.votes
                    voted = true if player._id.equals(p.id)
                return if voted

                currVote.votes.push
                    id      : player._id
                    vote    : data

                #Check for vote end
                if currVote.votes.length == game.players.length
                    vs = ((if v.vote then 1 else 0) for v in currVote.votes)
                    vs = vs.sum()
                    vote_passed = vs > (game.players.length - vs)
                    vote_count = 0
                    if vote_passed
                        game.state = GAME_QUEST
                    else
                        game.state = GAME_PROPOSE

                        #Check for too many failed votes
                        for v in game.votes
                            if v.mission == game.currentMission
                                vote_count += 1

                        if vote_count == 5
                            currMission = game.missions[game.currentMission]
                            currMission.status = 1
                            game.check_for_game_end()

                    game.set_next_leader(vote_passed || vote_count == 5)
                game.save()
                send_game_info(game)

    socket.on 'quest', (data) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                currVote = game.votes[game.votes.length - 1]

                #Check that the player is on the mission team
                for t in currVote.team
                    in_team = true if player._id.equals(t)
                return if not in_team

                #Check that the player hasn't already "put in a card"
                currMission = game.missions[game.currentMission]
                for p in currMission.players
                    return if player._id.equals(p.id)

                #Check that player is allowed to fail if they did
                if data == false
                    p = game.get_player(player._id)
                    return if not p
                    if not p.isEvil
                        data = true

                currMission.players.push
                    id          : player._id
                    success     : data

                if currMission.players.length == currMission.numReq
                    #See if the mission succeeded or failed
                    fails = ((if p.success then 0 else 1) for p in currMission.players)
                    fails = fails.sum()
                    if fails >= currMission.failsReq
                        currMission.status = 1
                    else
                        currMission.status = 2

                    game.check_for_game_end()
                    game.save()
                    send_game_info(game)
                else
                    game.save()

    socket.on 'assassinate', (t) ->
        socket.get 'player', (err, player) ->
            return if err || not player
            Game.findById player.currentGame, (err, game) ->
                return if err || not game
                return if game.state != GAME_ASSASSIN

                target = game.get_player(t)
                return if not target

                game.state = GAME_FINISHED
                game.assassinated = target.id
                if target.role == "Merlin"
                    game.evilWon = true
                else
                    game.evilWon = false

                game.save()
                send_game_info(game)

    socket.on 'leavegame', () ->
        socket.join('lobby')
        socket.get 'player', (err, player) ->
            return if err || not player
            player.leave_game (err, game) ->
                if game then send_game_info(game)
                send_game_list()
  
    socket.on 'disconnect', () ->
        #Do we need to do something here?
        return
