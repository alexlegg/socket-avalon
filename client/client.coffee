jQuery ->
    #Socket.io stuff
    
    query = ""
    if $.cookie('player_id')
        query = "?player_id=" + $.cookie('player_id')

    socket = io.connect('http://' + IP + ":" + PORT + query)

    socket.on 'connect', (data) ->
        $("#disconnected").hide()

        if not $.cookie('player_id')
            $("#signin").show()

    socket.on 'disconnect', () ->
        $("#signin").hide()
        $("#lobby").hide()
        $("#pregame").hide()
        $("#game").hide()
        $("#disconnected").show()

    GAME_LOBBY         = 0
    GAME_PREGAME       = 1
    GAME_PROPOSE       = 2
    GAME_VOTE          = 3
    GAME_PTRC_PROPOSE  = 4
    GAME_PTRC_VOTE     = 5
    GAME_QUEST         = 6
    GAME_LADY          = 7
    GAME_ASSASSIN      = 8
    GAME_FINISHED      = 9

    socket.on 'player_id', (player_id) ->
        $.cookie('player_id', player_id, {expires: 365})
        $("#login").hide()

    socket.on 'previous_game', () ->
        $("#btn_reconnect").show()

    socket.on 'bad_login', () ->
        $("#signin").show()
        #$.removeCookie('player_id')
        
    socket.on 'reconnectlist', (games) ->
        $("#login").show()
        for g in games
            do (g) ->
                join_btn = $('<a>')
                    .addClass("list-group-item")
                    .text(g.name)
                    .append($('<span>').addClass("pull-right").text(g.num_players))
                    .click () ->
                        socket.emit 'reconnectuser', { game_id : g.id, player_id : g.player }
                        $("#reconnectlist").hide()
                        $("#reconnectmessage").text("Waiting for approval to reconnect")
                        $("#reconnectmessage").show()

                $("#reconnectlist").append(join_btn)
            $("#reconnectmessage").text("")
            $("#reconnectmessage").hide()
            $("#reconnectlist").show()

    socket.on 'reconnectdenied', () ->
        $("#reconnectmessage").text("You were rejected")


    socket.on 'gamelist', (games) ->
        return if $("#pregame").is(":visible")
        return if $("#game").is(":visible")

        $("#lobby").show()
        $("#gamelist").empty()
        for g in games
            do (g) ->
                join_btn = $('<a>')
                    .addClass("list-group-item")
                    .text(g.name)
                    .append($('<span>').addClass("pull-right").text(g.num_players))
                    .click () ->
                        socket.emit 'joingame', { game_id : g.id }

                $("#gamelist").append(join_btn)

    socket.on 'kicked', () ->
        $("#pregame").hide()
        $("#game").hide()

    socket.on 'gameinfo', (game) ->
        $("#lobby").hide()

        if game.state == GAME_LOBBY
            $("#pregame").show()
            $("#gameinfo").empty()
            $("#btn_start_game").hide()
            $("#gameoptions").hide()

            ishost = false
            for p, i in game.players
                li = $('<li>')
                    .addClass("list-group-item")
                    .text(p.name)

                if ishost then do (p) ->
                    kick_btn = $("<button>")
                        .addClass("pull-right")
                        .addClass("btn")
                        .addClass("btn-danger")
                        .addClass("btn-xs")
                        .text("Kick")
                        .on 'click', (e) ->
                            socket.emit('kick', p.id)

                    li.append(kick_btn)

                if game.me.id == p.id && i == 0
                    ishost = true

                $("#gameinfo").append li

            if ishost
                $("#btn_ready").show()
            else
                $("#btn_ready").hide()

            window.have_game_info = false

        else if game.state == GAME_FINISHED
            socket.emit 'leavegame'
            window.location = '/game?id=' + game.id

            ###
            $("#game").show()

            #Draw mission info
            lastmission = undefined
            for m, i in game.missions
                $("#mission" + i).text(m.numReq)
                if m.failsReq == 2
                    $("#mission" + i).append("*")
                if m.status == 1
                    lastmission = m
                    $("#mission" + i).addClass("evil")
                else if m.status == 2
                    lastmission = m
                    $("#mission" + i).addClass("good")

            if game.evilWon
                $("#missionmessage")
                    .removeClass("good")
                    .addClass("evil")
                    .text("Game Over. The Minions of Mordred win!")
            else
                $("#missionmessage")
                    .removeClass("evil")
                    .addClass("good")
                    .text("Game Over. The Servants of Arthur win!")

            if game.assassinated != undefined
                $("#missionmessage").append("<br />" + game.assassinated + " was assassinated.")
            ###

        else if game.state == GAME_PREGAME
            $("#pregame").show()
            $("#btn_ready").hide()
            $("#btn_leavelobby").hide()
            $("#btn_start_game").hide()
            $("#gameoptions").hide()

            if window.have_game_info == true
                return

            $("#gameinfo").empty()

            ishost = false
            for p, i in game.players
                player_id = $("<input>")
                    .attr("type", "hidden")
                    .attr("value", p.id)
                li = $('<li>')
                    .addClass("list-group-item")
                    .text(p.name)
                    .attr("id", "player" + i)
                    .append(player_id)

                $("#gameinfo").append li
                if game.me.id == p.id && i == 0
                    ishost = true
                    $("#btn_start_game").show()
                    $("#gameoptions").show()
                    $("#gameinfo").sortable
                        items : "li:not(:first)"

            if not ishost
                $("#waitforhost").show()

            window.have_game_info = true

        else
            $("#pregame").hide()
            $("#game").show()

            #Draw mission info
            lastmission = undefined
            for m, i in game.missions
                $("#mission" + i).text(m.numReq)
                if m.failsReq == 2
                    $("#mission" + i).append("*")
                if m.status == 1
                    lastmission = m
                    $("#mission" + i).addClass("evil")
                else if m.status == 2
                    lastmission = m
                    $("#mission" + i).addClass("good")
                else
                    $("#mission" + i).removeClass("good")
                    $("#mission" + i).removeClass("evil")

            #Notify about last mission
            if game.state == GAME_PROPOSE
                $("#missionmessage")
                    .removeClass("good")
                    .removeClass("evil")

                #Show vote count
                votecount = 0
                for v in game.votes
                    if v.mission == game.currentMission
                        votecount += 1

                if votecount > 0
                    $("#missionmessage")
                        .text("Failed voting rounds: " + votecount)
                else if lastmission != undefined
                    if lastmission.status == 1
                        $("#missionmessage")
                            .addClass("evil")
                            .text("Mission failed! It was probably Dan.")

                        if game.options.showfails
                            if lastmission.numfails == 1
                                $("#missionmessage").append("<br />There was only 1 fail.")
                            else
                                $("#missionmessage").append("<br />There were " + lastmission.numfails + " fails.")
                    else
                        $("#missionmessage")
                            .addClass("good")
                            .text("Mission succeeded!")
                else
                    $("#missionmessage").text("")

            if game.state == GAME_QUEST
                $("#missionmessage")
                    .removeClass("good")
                    .removeClass("evil")
                    .text("Mission is underway...")

            if game.state == GAME_LADY
                $("#missionmessage")
                    .removeClass("good")
                    .removeClass("evil")

            if game.state == GAME_ASSASSIN
                $("#missionmessage")
                    .removeClass("good")
                    .removeClass("evil")
                    .text("The Assassin can now try to kill Merlin.")

            #Draw the list of players
            me = game.me
            $("#players").empty()
            for p in game.players
                li = $("<li>")
                    .addClass("list-group-item")
                    .text(p.name)

                icons = $("<span>")
                    .addClass("pull-right")
                    .attr(style : "font-size: 16px;")

                #Add an icon to the leader
                if game.currentLeader == p.id
                    icons.append('<img class="icon" src="crown.png" />')

                #Add an icon to the final leader
                if game.finalLeader == p.id
                    icons.append('<img class="icon" src="crown-last.png" />')

                #Add an icon to the player with the lady of the lake
                if game.lady == p.id
                    icons.append('<img class="icon" src="female.png" />')

                #Add an icon to the players who have been lady of the lake
                if game.state == GAME_LADY && p.id in game.pastLadies
                    icons.append('<img class="icon" src="cross.png" />')

                if game.state == GAME_VOTE || game.state == GAME_QUEST ||
                   game.state == GAME_PTRC_VOTE
                    currVote = game.votes[game.votes.length - 1]

                    #Highlight proposed team
                    if p.id in currVote.team
                        #icons.append('\u2694')
                        li.addClass("success")

                    #Hourglass next to players that haven't voted
                    voted = []
                    if currVote.votes
                        (voted.push v.id) for v in currVote.votes
                    if not (p.id in voted)
                        icons.append('<img class="icon" src="clock.png" />')

                if game.state == GAME_PTRC_PROPOSE || game.state == GAME_PTRC_VOTE
                    currVote = game.votes[game.votes.length - 1]

                    if currVote && currVote.mission == game.currentMission
                        #Highlight already accepted team
                        if p.id in currVote.accepted
                            #icons.append('\u2694')
                            li.addClass("ptrc_success")

                        #Highlight already rejected team
                        if p.id in currVote.rejected
                            #icons.append('\u2694')
                            li.addClass("ptrc_fail")

                if game.state == GAME_PROPOSE || game.state == GAME_QUEST ||
                   game.state == GAME_PTRC_PROPOSE
                    currVote = game.votes[game.votes.length - 1]
                    if currVote && currVote.mission == game.currentMission
                        #Add an icon for votes
                        for v in currVote.votes
                            if p.id == v.id
                                voteicon = if v.vote then 'tick' else 'cross'
                                icons.append('<img class="icon" src="' + voteicon + '.png" />')

                #Make players selectable for the leader (to propose quest)
                if game.currentLeader == me.id
                    mission_max = 0
                    if game.state == GAME_PROPOSE
                        mission = game.missions[game.currentMission]
                        mission_max = mission.numReq
                    else if game.state == GAME_ASSASSIN || game.state == GAME_PTRC_PROPOSE
                        mission_max = 1
                    window.mission_max = mission_max

                    prev_chosen = []
                    if game.votes.length > 0
                        currVote = game.votes[game.votes.length - 1]
                        prev_chosen = currVote.accepted.concat(currVote.rejected)

                    li.on 'click', (e) ->
                        select_for_mission(mission_max, prev_chosen, $(e.target))
                    input = $("<input>").attr
                        type    : 'hidden'
                        name    : p.id
                        value   : 0
                    li.append(input)

                #Make players selectable for the lady
                if game.state == GAME_LADY && game.lady == me.id
                    window.mission_max = 1
                    li.on 'click', (e) ->
                        select_for_lady(game.pastLadies, $(e.target))
                    input = $("<input>").attr
                        type    : 'hidden'
                        name    : p.id
                        value   : 0
                    li.append(input)

                li.append(icons)
                $("#players").append(li)

            #Make quest proposal button visible to leader
            if (game.state == GAME_PROPOSE || game.state == GAME_PTRC_PROPOSE) &&
               game.currentLeader == me.id
                $("#btn_select_mission").show()
                $("#leaderinfo").show()
            else
                $("#btn_select_mission").hide()
                $("#leaderinfo").hide()

            #Make assassination button visible to assassin
            if game.state == GAME_ASSASSIN && game.currentLeader == me.id
                $("#btn_assassinate").show()
            else
                $("#btn_assassinate").hide()

            #Make reveal button visible to player with the Lady of the Lake
            if game.state == GAME_LADY && game.lady == me.id
                $("#btn_reveal").show()
                $("#leaderinfo").html("You are the Lady of the Lake, select a player to reveal.")
                $("#leaderinfo").show()
            else
                $("#btn_reveal").hide()

            #Make voting panel visible during vote phase
            if game.state == GAME_VOTE || game.state == GAME_PTRC_VOTE
                currVote = game.votes[game.votes.length - 1]
                voted = []
                if currVote.votes
                    (voted.push v.id) for v in currVote.votes
                if not (me.id in voted)
                    $("#vote").show()
                else
                    $("#vote").hide()
            else
                $("#vote").hide()

            #Make questing panel visible during quest phase
            if game.state == GAME_QUEST
                currVote = game.votes[game.votes.length - 1]
                if me.id in currVote.team
                    $("#quest").show()
                else
                    $("#quest").hide()
            else
                $("#quest").hide()

            #Draw the hidden info box
            $("#hiddeninfo").empty()
            info = $("<span>").text(me.role)
            if me.isEvil
                info.addClass("evil")
            else
                info.addClass("good")
            li = $("<li>")
                .addClass("list-group-item")
                .text("You are ")
                .append(info)
            $("#hiddeninfo").append(li)

            for i in me.info
                info = $("<span>").text(i.information)
                if i.information == "evil" then info.addClass("evil")
                if i.information == "good" then info.addClass("good")
                li = $("<li>")
                    .addClass("list-group-item")
                    .text(i.otherPlayer + " is ")
                    .append(info)
                $("#hiddeninfo").append(li)

            #If someone is trying to reconnect show vote
            if game.reconnect_user && game.reconnect_user != ""
                if game.reconnect_vote[me.order] == 0
                    $("#user_reconnecting_name").text(game.reconnect_user)
                    $("#user_reconnecting").show()
            else
                $("#user_reconnecting").hide()
                $("#user_reconnecting .btn").each () ->
                    $(this).removeClass("active")

    #Regular jquery stuff
    
    $("#form-signin").on 'submit', (e) ->
        if $("#playername").val().length > 0
            socket.emit('login', {name: $("#playername").val()})
            $("#signin").hide()
        e.preventDefault()

    $("#btn_newgame").on 'click', () ->
        socket.emit 'newgame'

    $("#btn_changename").on 'click', () ->
        $("#signin").show()

    $("#btn_reconnect").on 'click', () ->
        socket.emit 'reconnecttogame'

    $("#btn_ready").on 'click', () ->
        socket.emit('ready')

    $("#btn_start_game").on 'click', () ->
        players = $("#gameinfo").sortable("toArray")
        sorted = {}
        for p, i in players
            input = $("#" + p + " input")[0]
            player_id = $(input).attr("value")
            sorted[player_id] = i + 1

        options = {}
        options['mordred'] = $("#opt_mordred").is(":checked")
        options['oberon'] = $("#opt_oberon").is(":checked")
        options['showfails'] = $("#opt_showfails").is(":checked")
        options['ladylake'] = $("#opt_ladylake").is(":checked")
        options['ptrc'] = $("#opt_ptrc").is(":checked")
        options['danmode'] = $("#opt_danmode").is(":checked")
        
        socket.emit('startgame', {order: sorted, options: options})

    $("#btn_showinfo").on 'click', () ->
        if $("#hiddeninfo").is(":visible")
            $("#btn_showinfo").text("Show Hidden Info")
        else
            $("#btn_showinfo").text("Hide Hidden Info")
        $("#hiddeninfo").toggle()

    $(".options-list li").on 'click', (e) ->
        e.preventDefault()
        chk = $(this).find("input").first()
        if chk
            chk.prop('checked', !chk.prop('checked'))

    $(".options-list input").on 'click', (e) ->
        e.stopPropagation()

    $("#form-select-mission").on 'submit', (e) ->
        e.preventDefault()
        mission = []
        sel = []
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            if input.val() == '1'
                mission.push input.attr('name')
                sel.push $(this)

        if mission.length == window.mission_max
            assassinate = $("#btn_assassinate").is(":visible")
            reveal = $("#btn_reveal").is(":visible")
            $("#btn_select_mission").hide()
            $("#btn_assassinate").hide()
            $("#btn_reveal").hide()
            for s in sel
                s.removeClass('active')
                s.addClass('success')
            $("#leaderinfo").html("You are the leader, select players from the list then press this button.")

            if assassinate
                socket.emit('assassinate', mission[0])
            else if reveal
                socket.emit('reveal', mission[0])
            else
                socket.emit('propose_mission', mission)
        else
            $("#leaderinfo").html("You must select only <b>" + window.mission_max + "</b> players for the quest!")

    $("#btn_submitvote").on 'click', (e) ->
        radio = $("input[name=vote]:checked").val()
        return if radio != "approve" && radio != "reject"
        vote = (radio == "approve")
        $("input[name=vote]:checked").prop('checked', false)
        $("#vote .btn").each () ->
            $(this).removeClass("active")
        $("#vote").hide()
        socket.emit('vote', vote)

    $("#btn_submitquest").on 'click', (e) ->
        radio = $("input[name=quest]:checked").val()
        return if radio != "success" && radio != "fail"
        quest_card = (radio == "success")
        $("input[name=quest]:checked").prop('checked', false)
        $("#quest .btn").each () ->
            $(this).removeClass("active")
        $("#quest").hide()
        socket.emit('quest', quest_card)

    $("#btn_quit").on 'click', (e) ->
        $("#game").hide()
        $("#btn_reconnect").show()
        socket.emit 'leavegame'

    $("#btn_leavelobby").on 'click', (e) ->
        $("#pregame").hide()
        socket.emit 'leavegame'

    $("#btn_submitreconnectvote").on 'click', (e) ->
        radio = $("input[name=reconnectvote]:checked").val()
        return if radio != "allow" && radio != "deny"
        rvote = (radio == "allow")
        $("input[name=reconnectvote]:checked").prop('checked', false)
        $("#user_reconnecting .btn").each () ->
            $(this).removeClass("active")
        $("#user_reconnecting").hide()
        socket.emit('reconnect_vote', rvote)

    $("#btn_noreconnect").on 'click', (e) ->
        socket.emit('noreconnect', {name: $("#playername").val()})
        $("#login").hide()


select_for_mission = (mission_max, prev_chosen, li) ->
    proposing = $("#btn_select_mission").is(":visible")
    assassinating = $("#btn_assassinate").is(":visible")
    if proposing || assassinating

        #Get how many already selected
        mission_count = 0
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            if mission_max == 1
                $(this).removeClass("active")
                input.attr(value: 0)
            else
                mission_count += 1 if input.val() == '1'

        #Toggle players if it won't exceed mission maximum
        input = $(li.children(":input")[0])
        player_id = input.attr("name")
        if li.hasClass("active")
            li.removeClass("active")
            input.attr(value: 0)
        else
            if player_id in prev_chosen
                $("#leaderinfo").html("You can't choose someone who has already been voted for")
            else if mission_count + 1 <= mission_max
                li.addClass("active")
                input.attr(value: 1)
            else
                $("#leaderinfo").html("You must select only <b>" + window.mission_max + "</b> players for the quest!")

select_for_lady = (pastLadies, li) ->
    revealing = $("#btn_reveal").is(":visible")
    if revealing
        #Remove selection from others
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            $(this).removeClass("active")
            input.attr(value: 0)

        #Toggle players if they are valid
        input = $(li.children(":input")[0])
        player_id = input.attr("name")
        if player_id in pastLadies
            $("#leaderinfo").html("You can't give Lady of the Lake to someone who has had it already")
        else
            li.addClass("active")
            input.attr(value: 1)
