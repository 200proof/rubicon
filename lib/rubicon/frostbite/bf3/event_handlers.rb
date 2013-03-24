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
                server.plugin_manager.dispatch_event("player.onSuicide", event_args)
            else
                killer_p = server.players[killer]
                victim_p = server.players[victim]

                killer_p.kills += 1 rescue p "#{killer} nil?"

                event_args = { killer: killer_p, victim: victim_p, weapon: weapon, headshot?: headshot }
                server.plugin_manager.dispatch_event("player.onKill", event_args)
            end
        end

        event "player.onChat" do |server, packet|
            event_name = packet.read_word
            player = server.players[packet.read_word]
            message = packet.read_word
            audience = packet.read_word

            # These are messages sent by other RCons, ignore them.
            return if player == "Server"

            if message[0] == "/"
                split_up = message.split " "
                command = split_up.shift
                command[0] = '' # remove the /
                args = { player: player, args: split_up}
                server.plugin_manager.dispatch_command(command, args)
            else
                event_args = {player: player, message: message, audience: audience }
                server.logger.info { "[CHAT] [#{audience}] <#{player.name}> #{message}" }
                server.plugin_manager.dispatch_event(event_name, event_args)
            end
        end

        event "player.onJoin" do |server, packet|
            event_name = packet.read_word
            player = packet.read_word
            guid = packet.read_word

            p = Player.new(server, player, guid)
            server.players[player] = p

            server.plugin_manager.dispatch_event(event_name, { player: p })
        end
    end
end