module Rubicon::Frostbite::BF3
    class Team
        attr_reader :id
        attr_accessor :tickets, :players, :squads

        def initialize(server, id)
            @id = id
            @players = PlayerCollection.new(server)
            @squads = []
            @tickets = 0

            # 0 = no squad, 32 squads per team
            33.times do |idx|
                @squads[idx] = Squad.new(server, self, idx)
            end
        end

        def add(player)
            if player.is_a? Player
                @players[player.name] = player
                @squads[player.squad_id].add player 
            else
                raise "#{player} is not a valid player!"
            end
        end

        def remove(player)
            if player.is_a? Player
                player.squad.remove player.name
                @players.delete player
            elsif player.is_a? String
                p = @players[player]
                p.squad.remove p
                @players.delete player
            else
                raise "#{player} is not a valid player!"
            end
        end

        def say(msg)
            @server.send_command("admin.say", msg, "team", @id)
        end

        def yell(msg, duration)
            @server.send_command("admin.yell", msg, duration, "team", @id)
        end

        def to_hash
            { id: @id, players: @players.values.sort { |a, b| b.score <=> a.score }.map { |player| player.to_hash } }
        end
    end
end