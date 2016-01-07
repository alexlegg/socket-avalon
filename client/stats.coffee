formatDate = (d) ->
    d = new Date(d)
    d_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    ampm = if (d.getHours() < 13) then "am" else "pm"
    h = d.getHours() % 12
    h = if h == 0 then 12 else h
    s = d_names[d.getDay()] + " " +
        d.getDate() + "/" +
        (d.getMonth() + 1) + "/" +
        d.getFullYear() + " " +
        h + ":" + d.getMinutes() + ampm

jQuery ->
    switch window.location.pathname
        when "/games"
            gamesReq = $.ajax
                url : '/api?type=games'

            gamesReq.done (res, status, jqXHR) ->
                if not res then return

                for r in res
                    li = $("<a>")
                        .addClass("list-group-item")
                        .prop("href", "/game?id=" + r.id)
                        .html($("<b>").text(formatDate(r.date)))
                        .append($("<br>"))
                        .append(r.name)
                    $("#gamelist").append(li)

        when "/game"
            gameReq = $.ajax
                url : '/api' + window.location.search + '&type=game'

            gameReq.done (res, status, jqXHR) ->
                if not res then alert "abort abort!"
                displayGame(res)

displayGame = (game) ->
    players = []
    for p in game.players
        players[p.id] = p

    if game.evilWon
        $("#gameover")
            .addClass("evil")
            .text("Game Over. The Minions of Mordred win!")
    else
        $("#gameover")
            .addClass("good")
            .text("Game Over. The Servants of Arthur win!")

    if game.assassinated != undefined
        target = players[game.assassinated]
        $("#missionmessage").append("<br />" + target.name + " was assassinated.")
    

    for p in game.players
        console.log("p", p)
        li = $('<li>')
                .addClass("list-group-item")
                .text(p.name)

        span = $('<span>')
                 .text(p.role)
                 .addClass("role")

        li.append(span)

        if p.isEvil
            li.addClass("evil")
        else
            li.addClass("good")

        $("#players").append(li)

    for m, mi in game.missions
        continue if m.players.length == 0

        a = $("<a>")
            .addClass("list-group-item")

        if m.status == 2
            sc = "good"
        else if m.status == 1
            sc = "evil"

        for p, i in m.players
            span = $("<span>")
                .addClass(sc)
                .text(players[p.id].name)
            if i != m.players.length - 1
                span.append(", ")
            if not p.success
                span.addClass("bold")

            a.append(span)

        table = $("<table>")
            .addClass("vote-table")

        player_votes = []
        for v in game.votes
            continue if v.mission != mi
            player_vote = []
            for mv in v.votes
                player_vote[mv.id] = mv.vote
            player_votes.push(player_vote)

        ###
        tr = $("<tr>")
        tr.append($("<th>").text(""))

        for x in [1..player_votes.length]
            tr.append($("<th>").text(x))

        table.append(tr)
        ###

        for pid, p of players
            ptr = $("<tr>")
            ptr.append($("<td>").text(p.name))

            for pv in player_votes
                td = $("<td>").addClass "vote_td"
                voteicon = if pv[pid] then "tick" else "cross"
                ptr.append("<img class=\"icon\" src=\"" + voteicon + ".png\" />")

            table.append(ptr)

        a.append(table)
        do (table) ->
            a.on "click", (e) ->
                table.toggle()

        $("#missions").append(a)
