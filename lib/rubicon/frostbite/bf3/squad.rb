module Rubicon::Frostbite::BF3
    class Squad
        def initialize(server, team, id)
            @server = server
            @team = team
            @id = id

            @players = {}
        end

        def add(player)
            if player.is_a? Player
                @players[player.name] = player
            else
                raise "#{player} is not a valid player!"
            end
        end

        def remove(player)
            if player.is_a? Player
                @players.delete player.name
            elsif player.is_a? String
                @players.delete player
            else
                raise "#{player} is not a valid player!"
            end
        end

        def say(msg)
            @server.connection.send_command("admin.say", msg, "squad", @id)
        end

        def yell(msg, duration)
            @server.connection.send_command("admin.say", msg, duration, "squad", @team.id, @id)
        end
    end
end