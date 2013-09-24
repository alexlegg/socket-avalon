socket = io.connect('http://' + document.domain)
socket.on 'connect', (data) ->
    console.log("connected")

socket.on 'gamelist', (games) ->
    $("#form-signin").hide()
    $("#lobby").show()
    $("#gamelist").empty()
    for g in games
        do (g) ->
            join_btn = $('<a>')
                .addClass("list-group-item")
                .text(g.name)
                .append($('<span>').addClass("badge").text(g.num_players))
                .click () ->
                    socket.emit 'joingame', { game_id : g.id }

            $("#gamelist").append(join_btn)

socket.on 'gameinfo', (game) ->
    $("#lobby").hide()
    if !game.started
        $("#pregame").show()
        $("#gameinfo").empty()
        for p in game.players
            ready = if p.ready then '\u2714' else '\u2715'
            li = $('<li>')
                .addClass("list-group-item")
                .text(p.name)
                .append($('<span>').addClass("badge").text(ready))
            $("#gameinfo").append li
    else
        $("#pregame").hide()
        $("#game").show()

        me = game.players[game.me]
        if me.isEvil
            $("#myrole").addClass("evil")
        else
            $("#myrole").addClass("good")
        $("#myrole").text(me.role)

        for i in me.info
            info = $("<span>").text(i.information)
            if i.information == "evil" then info.addClass("evil")
            li = $("<li>")
                .addClass("list-group-item")
                .text(i.otherPlayer + " is ")
                .append(info)
            $("#hiddeninfo").append(li)

jQuery ->
    $("#form-signin").on 'submit', (e) ->
        socket.emit 'newuser', {name: $("#playername").val()}
        e.preventDefault()

    $("#btn_newgame").on 'click', () ->
        socket.emit 'newgame'

    $("#btn_ready").on 'click', () ->
        if $("#btn_ready").text()  == "I am Ready"
            $("#btn_ready").text("I am not Ready")
        else
            $("#btn_ready").text("I am Ready")
        socket.emit 'ready'

    $("#btn_showinfo").on 'click', () ->
        if $("#hiddeninfo").is(":visible")
            $("#btn_showinfo").text("Show Hidden Info")
        else
            $("#btn_showinfo").text("Hide Hidden Info")
        $("#hiddeninfo").toggle()
