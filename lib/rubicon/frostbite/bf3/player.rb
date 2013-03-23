module Rubicon::Frostbite::BF3
    class Player
        attr_accessor :name, :guid, :score, :kills,
            :deaths, :rank

        def initialize(server, name, guid)
            @server = server
            @name = name
            @guid = guid
        end

        def team
            @server.teams[@team_id]
        end

        def team=(new_team)
            if new_team is_a? Number
                @team_id = new_team
            elsif new_team is_a? Team
                @team_id = new_team.id
            else
                raise "#{new_team} is not a valid team!"
            end
        end

        def squad
            @server.teams[@team_id].squads[@squad_id]
        end

        def squad=
            if new_squad is_a? Number
                @squad_id = squad
            elsif new_squad is_a? Squad
                @squad_id = new_squad.id
            else
                raise "#{new_squad} is not a valid squad!"
            end
        end

        def say(msg)
            @server.connection.send_command("admin.say", msg, "player", @name)
        end

        def yell(msg, duration)
            @server.connection.send_command("admin.yell", msg, duration, "player", @name)
        end

        def kick(reason=nil) 
            if reason
                @server.connection.send_command("admin.kickPlayer", @name, reason)
            else
                @server.connection.send_command("admin.kickPlayer", @name, reason)
            end
        end

        def kill
            @server.connection.send_command("admin.killPlayer", @name)
        end
    end
end