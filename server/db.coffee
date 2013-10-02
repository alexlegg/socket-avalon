db_url = "localhost"
mongoose = require('mongoose')

db = mongoose.connect(db_url)

#
# Database schema definition
#

GAME_LOBBY      = 0
GAME_PROPOSE    = 1
GAME_VOTE       = 2
GAME_QUEST      = 3
GAME_FINISHED   = 4

gameSchema = new mongoose.Schema
    state       : {type: Number, default: GAME_LOBBY}
    roles       : [
        name    : String
        isEvil  : Boolean
    ]
    players     : [
        id      : Number
        name    : String
        socket  : String
        ready   : Boolean
        role    : String
        isEvil  : Boolean
        info    : [
            otherPlayer : String
            information : String
        ]
    ]
    missions    : [
        numReq      : Number
        failsReq    : Number
        players     : [
            id      : Number
            success : Boolean
        ]
        status  : {type: Number, default: 0}
    ]
    votes       : [
        mission : Number
        team    : [Number]
        votes   : [
            id      : Number
            vote    : Boolean
        ]
    ]
    currentMission  : Number
    currentLeader   : Number

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (name, sock) ->
    new_id = this.players.length
    this.players.push
        id  : new_id
        name : name
        socket : sock
        ready : false
        role : undefined
        isEvil : undefined
        info : []

    return new_id

mission_reqs =
    5 : [2, 3, 2, 3, 3]
    6 : [2, 3, 4, 3, 4]
    7 : [2, 3, 3, 4, 4]
    8 : [3, 4, 4, 5, 5]
    9 : [3, 4, 4, 5, 5]
    10 : [3, 4, 4, 5, 5]

gameSchema.methods.setup_missions = () ->
    np = this.players.length
    for i in [0..4]
        this.missions.push
            numReq : mission_reqs[np][i]
            failsReq : if i == 3 && np >= 7 then 2 else 1
            players : []

    this.currentMission = 0

gameSchema.methods.set_next_leader = () ->
    set_next = false
    leader_set = false
    for p in this.players
        if set_next == true
            this.currentLeader = p.id
            leader_set = true
            break
        if p.id == this.currentLeader
            set_next = true
    if not leader_set
        this.currentLeader = this.players[0].id

Game = mongoose.model('Game', gameSchema)

