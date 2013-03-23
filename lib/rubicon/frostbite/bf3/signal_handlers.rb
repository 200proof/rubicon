class Rubicon::Frostbite::BF3::Server
    @@signal_handlers = {}
    def self.signal(sig, &block)
        @@signal_handlers[sig] = block
    end

    signal :refresh_server_info do |server|
        info = server.connection.send_request("serverinfo")

        info.read_word

        server.name = info.read_word
        server.players = info.read_word.to_i
        server.max_players = info.read_word.to_i
        server.game_mode = info.read_word
        server.current_map = info.read_word
        server.rounds_played = info.read_word.to_i
        server.rounds_total = info.read_word.to_i
        server.scores, server.score_target = info.read_team_scores
        server.online_state = info.read_word
        server.ranked = info.read_bool
        server.punkbuster = info.read_bool
        server.has_password = info.read_bool
        server.uptime = info.read_word.to_i
        server.round_time = info.read_word.to_i
        server.ip = info.read_word
        server.punkbuster_version = info.read_word
        server.join_queue = info.read_bool
        server.region = info.read_word
        server.closest_ping_site = info.read_word
        server.country = info.read_word,
        server.matchmaking = info.read_bool 
    end

    signal :refresh_scoreboard do |server|
        scoreboard_packet = server.connection.send_request("admin.listPlayers", "all")

        status, scoreboard = scoreboard.read_word, scoreboard.read_player_info_block

        scoreboard.each do |player|
            server.players[player.name] ||= Player.new(player["name"], player["guid"])
            server.players[player.name].name   = player["name"]
            server.players[player.name].guid   = player["guid"]
            server.players[player.name].team   = player["teamId"]
            server.players[player.name].squad  = player["squadId"]
            server.players[player.name].kills  = player["kills"]
            server.players[player.name].deaths = player["deaths"]
            server.players[player.name].score  = player["score"]
            server.players[player.name].rank   = player["rank"]
        end
    end
end