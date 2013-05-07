module Rubicon::Frostbite::BF3
    class Server
        COMMAND_PREFIXES = ['/', '!', '@']

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
                server.push_to_web_streams "suicide", { player: victim, weapon: weapon.name }
                server.plugin_manager.dispatch_event("player.onSuicide", event_args)
            else
                killer_p = server.players[killer]
                victim_p = server.players[victim]

                killer_p.kills += 1

                event_args = { killer: killer_p, victim: victim_p, weapon: weapon, headshot?: headshot }

                server.logger.event(:kill) { "[KILL] " + "#{killer} <#{"(*)" if headshot}#{weapon.name}> #{victim}" }
                server.push_to_web_streams "kill", { killer: killer, victim: victim, weapon: weapon.name, headshot: headshot }
                server.plugin_manager.dispatch_event("player.onKill", event_args)
            end
        end

        event "player.onChat" do |server, packet|
            event_name = packet.read_word
            player     = server.players[packet.read_word]
            message    = packet.read_word
            audience   = packet.read_word

            # Get the target for specific audiences
            audience += " #{packet.read_word}" if audience.match /player|team|squad/

            server.push_to_web_streams "chat", { time: Time.now.to_s, player: player.name, message: message, audience: audience }
            next if player.name == "Server"

            if COMMAND_PREFIXES.include? message[0]
                split_up     = message.split " "
                command      = split_up.shift
                trigger_char = command[0]

                command[0] = '' # remove the trigger char
                args = { player: player, args: split_up, trigger: trigger_char }
                server.logger.event(:command) { "[CMND] <#{player.name}> #{message}" }
                server.plugin_manager.dispatch_command(command, args)
            else
                event_args = {player: player, message: message, audience: audience }
                server.logger.event(:chat) { "[CHAT] [#{audience}] <#{player.name}> #{message}" }
                server.plugin_manager.dispatch_event(event_name, event_args)
            end
        end

        event "player.onJoin" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word
            player_guid = packet.read_word

            if server.disconnected_players[player_name]
                server.disconnected_players.delete player_name
            end

            # A player that has joined will not necessarily be in the game
            # Their game may crash, and as such, they are only added to the scoreboard
            # when their client is "authenticated".

            server.logger.event(:join) { "[JOIN] <#{player_name}> is joining the server!" }
            server.plugin_manager.dispatch_event(event_name, { name: player_name, guid: player_guid })
        end

        event "player.onAuthenticated" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word

            player_info = server.send_request("admin.listPlayers", "player", player_name)

            if (player_info.read_word == "OK")
                player = Player.from_info_block server, player_info.read_player_info_block.first
                server.players[player_name] = player

                server.plugin_manager.dispatch_event(event_name, { player: player })
                server.logger.event(:auth) { "[AUTH] <#{player_name}> has been authenticated!" }
            end
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

            player = server.players[player_name]
            player.disconnected
            
            server.players.delete player_name

            server.disconnected_players[player_name] = player

            event_args   = {
                player_name:  player_name,
                player_stats: player_stats
            }

            server.logger.event(:leave) { "[EXIT] <#{player_name}> has left the server!" }

            server.plugin_manager.dispatch_event(event_name, event_args)
        end

        event "player.onSquadChange" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word
            team        = packet.read_word.to_i
            squad       = packet.read_word.to_i

            unless server.disconnected_players[player_name]
                player      = server.players[player_name] ||= Player.new(server, player_name)
                old_squad = player.squad
                player.squad = squad
                new_squad = player.squad

                event_args = {
                    player: player,
                    old_squad: old_squad,
                    new_squad: new_squad
                }

                server.logger.event(:squad_change) { "[SQAD] <#{player_name}> has switched from #{old_squad.name} to #{new_squad.name}" }

                server.plugin_manager.dispatch_event(event_name, event_args)
            end
        end

        event "player.onTeamChange" do |server, packet|
            event_name  = packet.read_word
            player_name = packet.read_word
            team        = packet.read_word.to_i
            squad       = packet.read_word.to_i

            unless server.disconnected_players[player_name]
                player      = server.players[player_name] ||= Player.new(server, player_name)

                old_team    = player.team
                player.team = team
                new_team    = player.team

                event_args = {
                    player: player,
                    old_team: old_team,
                    new_team: new_team
                }

                server.logger.event(:squad_change) { "[TEAM] <#{player_name}> has switched from team #{old_team.id} to team #{new_team.id}" }
                server.plugin_manager.dispatch_event(event_name, event_args)
            end
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

        event "server.onRoundOver" do |server, packet|
            server.process_signal(:refresh_scoreboard)
            server.logger.event(:round_over) { "[GAME] The round has ended." }
            server.push_to_web_streams "round_over", {}
            server.plugin_manager.dispatch_event("server.onRoundOver", { })
        end

        event "server.onLevelLoaded" do |server, packet|
            server.process_signal(:refresh_scoreboard)

            server.logger.event(:round_starting) { "[GAME] A new round will begin shortly." }
            server.push_to_web_streams "round_starting", {}
            server.plugin_manager.dispatch_event("server.onLevelLoaded", { })
        end
    end
end