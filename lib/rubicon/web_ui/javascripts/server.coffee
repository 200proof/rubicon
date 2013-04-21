#include "server/state"
#include "server/scoreboard"
#include "server/log"
#include "server/chat"
#include "server/ban_list"
#include "server/reserved_list"
#include "server/player_modal"

setupSSE = (serverState, logVM) ->
    window.EventStream = new EventSource "#{window.APIPath}/stream"

    EventStream.addEventListener "log", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = "info"
        logVM.addLogItem(logMessage)
        return
    , false

    EventStream.addEventListener "event", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = ""
        logVM.addLogItem(logMessage)
        return
    , false

    EventStream.addEventListener "scoreboard", (event) ->
        scoreboard = $.parseJSON(event.data)
        serverState.updateScoreboard(scoreboard)
        serverState.loadedAtLeastOnce(true)
        return
    , false

    EventStream.addEventListener "team_scores", (event) ->
        teamScores = $.parseJSON(event.data)
        serverState.updateTeamScores(teamScores)
        return
    , false

    EventStream.addEventListener "chat", (event) ->
        messageInfo = $.parseJSON(event.data)
        serverState.addChatMessage(messageInfo)
        return
    , false

$ ->
    window.APIPath = "#{window.location.pathname}/api"

    window.ServerState    = new ServerModel()
    window.LogVM          = new LogViewModel()
    window.ChatVM         = new ChatViewModel()
    window.ScoreboardVM   = new ScoreboardViewModel()
    window.BanListVM      = new BanListViewModel()
    window.ReservedListVM = new ReservedListViewModel()
    window.PlayerModalVM  = new PlayerModalViewModel()

    setupSSE(window.ServerState, window.LogVM)

    ko.applyBindings
        "logStream":    window.LogVM,
        "chatMessages": window.ChatVM,
        "scoreboard":   window.ScoreboardVM,
        "banList":      window.BanListVM,
        "reservedList": window.ReservedListVM,
        "playerModal":  window.PlayerModalVM,

    window.LogVM.hookEvents()
    window.ChatVM.hookEvents()
    window.BanListVM.hookEvents()
    window.ReservedListVM.hookEvents()
    window.PlayerModalVM.hookEvents()

    $("input.player-name").typeahead
        source: window.ServerState.playerNames

    return
