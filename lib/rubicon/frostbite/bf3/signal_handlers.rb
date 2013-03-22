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
end