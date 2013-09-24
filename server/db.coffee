db_url = "localhost"
mongoose = require('mongoose')

db = mongoose.connect(db_url)

#
# Database schema definition
#

gameSchema = new mongoose.Schema
    started     : {type: Boolean, default: false}
    roles       : [
        name    : String
        isEvil  : Boolean
    ]
    players     : [
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

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (name, sock) ->
    this.players.push
        name : name
        socket : sock
        ready : false
        role : undefined
        isEvil : undefined
        info : []

Game = mongoose.model('Game', gameSchema)

