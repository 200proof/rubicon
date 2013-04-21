class PlayerModalViewModel
    constructor: (chatVM) ->
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

        @sendChat = (yell) ->
            message  = $("input[name=send-player-message]").val()
            audience = "player #{self.currentModalPlayer().name()}"

            chatVM.sendChat message, audience, yell