class PlayerModalViewModel
    constructor: ->
        self = @
        @currentModalPlayer = ko.observable()

        @openPlayerModal = (user) ->
            self.currentModalPlayer(user)
            return

        @closePlayerModal = ->
            self.currentModalPlayer(undefined)
            return

        @hookEvents = ->
            # Chat events are hooked in chat.coffee
            return