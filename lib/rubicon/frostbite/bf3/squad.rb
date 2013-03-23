module Rubicon::Frostbite::BF3
    class Squad
        def initialize(server, team, id)
            @server = server
            @team = team
            @id = id
        end

        def say(msg)
            @server.connection.send_command("admin.say", msg, "squad", @id)
        end

        def yell(msg, duration)
            @server.connection.send_command("admin.say", msg, duration, "squad", @team.id, @id)
        end
    end
end