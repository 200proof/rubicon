class ScoreboardViewModel
    constructor: ->
        self = @
        @targetScore = window.ServerState.targetScore
        @teams = window.ServerState.teams

        @hasPlayers = ko.computed ->
            for team in @teams()
                if team.players().length != 0
                    return true

            false
        , @

        @nonNeutralTeams = ko.computed ->
            self.teams()[1..16]

        @neutralPlayers = ko.computed ->
            self.teams()[0]

        @hasNeutralPlayers = ko.computed ->
            self.neutralPlayers().players().length > 0

        @highlightSquadmates = (player) ->
            $("#team-#{player.team().id()} .squad-#{player.squad()}").addClass("squad-highlight")
            return

        @removeSquadmateHighlights = (player) ->
            $("#team-#{player.team().id()} .squad-#{player.squad()}.squad-highlight").removeClass("squad-highlight")
            return