module Rubicon::Frostbite::BF3
    class Squad
        FRIENDLY_NAMES = %w[
            No\ Squad Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo
            Lima Mike Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey X-ray
            Yankee Haggard Sweetwater Preston Redford Faith Celeste
        ]
        def initialize(server, team, id)
            @server = server
            @team = team
            @id = id

            @players = PlayerCollection.new(server)
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
            @server.send_command("admin.say", msg, "squad", @id)
        end

        def yell(msg, duration)
            @server.send_command("admin.say", msg, duration, "squad", @team.id, @id)
        end

        def name
            FRIENDLY_NAMES[@id]
        end
    end
end