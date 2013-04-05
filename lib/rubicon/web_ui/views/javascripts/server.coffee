class TeamModel
    constructor: (id, players, targetScore) ->
        @id = ko.observable id
        @players = ko.observable players
        @score = ko.observable 0
        @targetScore = ko.observable(targetScore)

        @progressBarWidth = ko.computed ->
            widthPercentage = (@score()/@targetScore()) * 100
            "#{widthPercentage}%"
        , @

class ScoreboardViewModel
    constructor: ->
        @recomputeDummy = ko.observable() # because somebody really hates me

        @teams = ko.observableArray([new TeamModel(0, [])])
        @targetScore = ko.observable(0)
        @hasPlayers = ko.computed ->
            allEmpty = true

            for team in @teams()
                if team.players().length != 0
                    allEmpty = false
                    break

            !allEmpty
        , @

        @nonNeutralTeams = ko.computed ->
            teams = @teams()
            teams[1...16]
        , @

        @neutralPlayers = ko.computed ->
            teams = @teams()
            teams[0]
        , @

        @hasNeutralPlayers = ko.computed ->
            @neutralPlayers().players.length > 0
        , @

        @updateScoreboard = (json) ->
            for team in json
                @teams()[team.id] = new TeamModel(team.id, team.players, @targetScore())

            @teams.valueHasMutated()

        @updateTeamScores = (json) ->
            @targetScore(json["target"]) if @targetScore() != json["target"]
            @teams()[index].score(score) for score, index in json["scores"]

            @teams.valueHasMutated()

class LogStreamViewModel
    constructor: ->
        @logItems = ko.observableArray()
        @stickyAutoscroller = (forceScroll) ->
            height = $(".tab-pane#log > table").height()
            scroll = $(".tab-pane#log").scrollTop()
            tolerance = $(".tab-pane#log").height() + 50

            if ((height - scroll) < tolerance || forceScroll == true)
                $(".tab-pane#log").scrollTop(height)

            return

        @addLogItem = (msg) ->
            @logItems.push (msg)

setupSSE = ->
    window.RubiconStreamSource = new EventSource "#{window.location.pathname}/api/stream"

    RubiconStreamSource.addEventListener "log", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = "info"
        window.RubiconLogStream.addLogItem(logMessage)
        return
    , false

    RubiconStreamSource.addEventListener "event", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = ""
        window.RubiconLogStream.addLogItem(logMessage)
        return
    , false

    RubiconStreamSource.addEventListener "scoreboard", (event) ->
        scoreboard = $.parseJSON(event.data)
        window.RubiconScoreboard.updateScoreboard(scoreboard)
        return
    , false

    RubiconStreamSource.addEventListener "team_scores", (event) ->
        teamScores = $.parseJSON(event.data)
        window.RubiconScoreboard.updateTeamScores(teamScores)
        return
    , false

$ ->
    window.RubiconLogStream = new LogStreamViewModel()
    window.RubiconScoreboard = new ScoreboardViewModel()

    ko.applyBindings
        "logStream": window.RubiconLogStream,
        "scoreboard": window.RubiconScoreboard

    $("a[data-target=#log]").on "shown", ->
        window.RubiconLogStream.stickyAutoscroller(true)

    setupSSE()

    return
