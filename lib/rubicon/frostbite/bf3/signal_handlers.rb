module Rubicon::Frostbite::BF3
    class Server
        @@signal_handlers = {}
        def self.signal(sig, &block)
            @@signal_handlers[sig] = block
        end

        signal :shutdown do |server|
            server.connection.message_channel.close
        end

        signal :refresh_server_info do |server|
            info = server.connection.send_request("serverinfo")

            info.read_word

            server.name = info.read_word
            info.read_word #players online
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
            server.country = info.read_word
            server.matchmaking = info.read_bool 
        end

        signal :refresh_scoreboard do |server|
            scoreboard_packet = server.connection.send_request("admin.listPlayers", "all")

            status, scoreboard = scoreboard_packet.read_word, scoreboard_packet.read_player_info_block

            scoreboard.each do |player|
                name = player["name"]
                server.players[name] ||= Player.new(server, player["name"], player["guid"])
                server.players[name].team   = player["teamId"].to_i
                server.players[name].squad  = player["squadId"].to_i
                server.players[name].kills  = player["kills"].to_i
                server.players[name].deaths = player["deaths"].to_i
                server.players[name].score  = player["score"].to_i
                server.players[name].rank   = player["rank"].to_i
            end
        end
    end
end