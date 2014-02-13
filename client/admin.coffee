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
    gamesReq = $.ajax
        url : '/api?type=games&gamestate=0'

    gamesReq.done (res, status, jqXHR) ->
        if not res then return

        for r in res
            do (r) ->
                li = $("<a>")
                    .addClass("list-group-item")
                    .html($("<b>").text(formatDate(r.date)))
                    .append($("<br>"))
                    .append(r.name)
                    .click () ->
                        delete_game(r.id)
                $("#gamelist").append(li)
                $("#gamelist").show()

delete_game = (id) ->
    deleteReq = $.ajax
        url : '/api?type=deletegame&id=' + id

    deleteReq.done (res, status, jqXHR) ->
        location.reload()
