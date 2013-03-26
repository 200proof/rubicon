module Rubicon::Frostbite::BF3
    class Server
        @@event_handlers = {}
        def self.event(sig, &block)
            @@event_handlers[sig] = block
        end

        event "player.onKill" do |server, packet|
            event_name = packet.read_word
            
            killer    = packet.read_word
            victim    = packet.read_word
            weapon    = Rubicon::Frostbite::BF3::WEAPONS[packet.read_word]
            headshot  = packet.read_bool

            if (killer == "") || (killer == victim)
                event_args = { player: server.players[victim], weapon: weapon }

                server.logger.event(:suicide) { "[SCDE] #{victim} killed themselves via #{weapon.name}" }

                server.plugin_manager.dispatch_event("player.onSuicide", event_args)
            else
                killer_p = server.players[killer]
                victim_p = server.players[victim]

                killer_p.kills += 1

                event_args = { killer: killer_p, victim: victim_p, weapon: weapon, headshot?: headshot }

                server.logger.event(:kill) { "[KILL] " + "#{killer} <#{"(*)" if headshot}#{weapon.name}> #{victim}" }

                server.plugin_manager.dispatch_event("player.onKill", event_args)
            end
        end

        event "player.onChat" do |server, packet|
            event_name = packet.read_word
            player     = server.players[packet.read_word]
            message    = packet.read_word
            audience   = packet.read_word

            # These are messages sent by other RCons, ignore them.
            next if player.name == "Server"

            if message[0] == "/"
                split_up = message.split " "
                command = split_up.shift
                command[0] = '' # remove the /
                args = { player: player, args: split_up}
                server.logger.event(:command) { "[CMND] <#{player.name}> #{message}" }
                server.plugin_manager.dispatch_command(command, args)
            else
                event_args = {player: player, message: message, audience: audience }
                server.logger.event(:chat) { "[CHAT] [#{audience}] <#{player.name}> #{message}" }
                server.plugin_manager.dispatch_event(event_name, event_args)
            end
        end

        event "player.onAuthenticated" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word

            server.players[player_name] ||= Player.new(server, player_name)

            server.logger.event(:auth) { "[AUTH] <#{player_name}> has been authenticated!" }
        end

        event "player.onJoin" do |server, packet|
            event_name = packet.read_word
            player     = packet.read_word
            guid       = packet.read_word

            p = (server.players[player] ||= Player.new(server, player, guid))
            p.guid = guid

            server.logger.event(:join) { "[JOIN] <#{player}> has joined the server!" }

            server.plugin_manager.dispatch_event(event_name, { player: p })
        end

        event "player.onSpawn" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word
            team        = packet.read_word.to_i

            player      = server.players[player_name]
            player.team = team

            server.logger.event(:spawn) { "[SPWN] <#{player_name}> has spawned." }

            server.plugin_manager.dispatch_event(event_name, { player: player })
        end

        event "player.onLeave" do |server, packet|
            event_name   = packet.read_word
            player_name  = packet.read_word
            player_stats = packet.read_player_info_block.first

            p = server.players[player_name]
            p.disconnected
            server.players.delete player_name

            event_args   = {
                player_name:  player_name,
                player_stats: player_stats
            }

            server.logger.event(:leave) { "[EXIT] <#{player_name}> has left the server!" }

            server.plugin_manager.dispatch_event(event_name, event_args)
        end

        event "player.onSquadChange" do |server, packet|
            event_name  = packet.read_word
            player_name = server.players[packet.read_word]
            team        = packet.read_word.to_i
            squad       = packet.read_word.to_i

            player      = server.players[player_name] ||= Player.new(server, player_name)

            old_squad = player.squad
            player.squad = squad
            new_squad = player.squad

            event_args = {
                player: player,
                old_squad: old_squad,
                new_squad: new_squad
            }

            server.plugin_manager.dispatch_event(event_name, event_args)
        end

        event "player.onTeamChange" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word
            team        = packet.read_word.to_i
            squad       = packet.read_word.to_i

            player      = server.players[player_name] ||= Player.new(server, player_name)

            old_team    = player.team
            player.team = team
            new_team    = player.team

            event_args = {
                player: player,
                old_team: old_team,
                new_team: new_team
            }

            server.plugin_manager.dispatch_event(event_name, event_args)
        end

        event "punkBuster.onMessage" do |server, packet|
            event_name = packet.read_word
            message    = packet.read_word

            server.plugin_manager.dispatch_event(event_name, { message: message })
        end

        event "server.onMaxPlayerCountChange" do |server, packet|
            event_name = packet.read_word
            count      = packet.read_word.to_i

            server.max_players = count

            server.plugin_manager.dispatch_event(event_name, { count: count })
        end
    end
end