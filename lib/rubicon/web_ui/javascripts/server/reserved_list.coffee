class ReservedListViewModel
    constructor: ->
        self = @
        @entries = ko.observableArray([])
        @refreshEntries = ->
            self.entries([])
            $("#reserved-list #new-slot").hide()
            $("#reserved-list .loading-row").show()
            $.getJSON "#{window.APIPath}/reserved-slots", (json) ->
                $("#reserved-list .loading-row").hide()
                $("#reserved-list #new-slot").show()
                self.entries(json)
                return

        @currentModalSlot = ko.observable()
        @openRemoveModal = (username) ->
            self.currentModalSlot(username)
            return

        @closeRemoveModal = ->
            self.currentModalSlot(undefined)
            return

        @removeSlot = (name) ->
            $.ajax
                method:  "DELETE"
                url:     "#{window.APIPath}/reserved-slots/#{name}"
                success: (e) ->
                    self.refreshEntries()
                    return

            self.closeRemoveModal()
            return

        @addSlot = (inputField) ->
            name = inputField.value

            return if name == ""

            $(inputField).attr "disabled", true
            $(inputField).val("Adding #{name}...")

            $.ajax
                method:  "PUT"
                url:     "#{window.APIPath}/reserved-slots/#{name}"
                success: (e) ->
                    $(inputField).attr "disabled", false
                    $(inputField).val ""
                    self.refreshEntries()
                    return

            return

        # Event bindings
        @hookEvents = ->
            $("a[data-target=#reserved-list]").on "shown", ->
                self.refreshEntries()
                return

            $("input[name=new-slot-name]").bind "keypress", (e) ->
                self.addSlot(e.target) if (e.which == 13)
                return