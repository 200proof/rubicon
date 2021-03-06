class BanModel
    constructor: (json) ->
        prefixes = {
            "name": "Name",
            "ip": "IP Address",
            "guid": "GUID"
        }

        @json   = json
        @id     = ko.observable json.id
        @idType = ko.observable json.id_type
        @reason = ko.observable json.reason

        @friendly_id = ko.computed ->
            "#{prefixes[@json.id_type]}: #{@json.id}"
        , @

        @expires = ko.computed ->
            switch @json.ban_type
                when "perm"
                    "Never"
                when "seconds"
                    expiry = new Date(Date.now() + (@json.seconds_left*1000))
                    "#{expiry.toRelativeTime()}"
                when "rounds"
                    "in #{@json.rounds_left} rounds"
        , @


class BanListViewModel
    constructor: (serverState) ->
        self = @
        @entries = ko.observableArray([])
        @refreshEntries = ->
            self.entries([])
            $("#ea-ban-list .loading-row").show()
            $.getJSON "#{window.APIPath}/ban-list", (json) ->
                self.entries.push(new BanModel(entry)) for entry in json
                $("#ea-ban-list .loading-row").hide()
                return

        @currentModalBan = ko.observable()
        @openBanModal = (banEntry) ->
            self.currentModalBan(banEntry)
            return

        @closeBanModal = ->
            self.currentModalBan(undefined)
            return

        @removeBan = (ban) ->
            serverState.lockInputs()
            $.ajax
                method: "DELETE",
                url:    "#{window.APIPath}/ban-list/#{ban.idType()}/#{ban.id()}",
                success: (response) ->
                    serverState.unlockInputs(true)
                    self.closeBanModal()
                    self.refreshEntries()
                    return

            return

        @hookEvents = ->
            $("a[data-target=#ban-list]").on "shown", ->
                self.refreshEntries()