io = require('socket.io')
express = require('express')
app = express()
server = app.listen(PORT)

app.configure () ->
    app.use express.static(__dirname + '/js')
    app.use express.static(__dirname + '/css')

app.get '/', (req, res) ->
    res.set('Pragma', 'no-cache')
    res.sendfile(__dirname + '/html/index.html')

io = io.listen server
io.set('transports', ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'])

if DEBUG
    io.set('log level', 3)
else
    io.set('log level', 0)
    io.enable('browser client minification')
