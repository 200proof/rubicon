module Rubicon::Frostbite::BF3
    class Team
        attr_reader :id
        attr_accessor :players, :squads

        def initialize(server, id)
            @id = id
            @players = []
            @squads = []

            # 0 = no squad, 32 squads per team
            33.times do |idx|
                @squads[idx] = Squad.new(server, self, idx)
            end
        end

        def say(msg)
            @server.connection.send_command("admin.say", msg, "team", @id)
        end

        def yell(msg, duration)
            @server.connection.send_command("admin.yell", msg, duration, "team", @id)
        end
    end
end