class ServerPageViewModel
    @players = ko.observableArray([])

$ ->
    ko.applyBindings new ServerPageViewModel