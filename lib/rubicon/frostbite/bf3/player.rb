module Rubicon::Frostbite::BF3

    # Allows us to have a special player object for any events which are 
    # emitted by the game server without it polluting the actual collection.
    class PlayerCollection < Hash
        def initialize(server)
            @server_player = SpecialPlayer.new(server, "Server")
            super()
        end

        def [](key)
            key == "Server" ? @server_player : super(key)
        end

        def []=(key, value)
            key == "Server" ? value : super(key, value)
        end

        # Converts this player collection and all its players into a hash.
        # Useful for converting to JSON
        def to_hash
            ret = {}

            each do |name, player|
                ret[name] = player.to_hash
            end

            ret
        end
    end

    class Player
        NO_GUID = "NO_GUID"

        # Creates a player from a player info block.
        def self.from_info_block(server, info_block_hash)
            player = Player.new(server, info_block_hash["name"], info_block_hash["guid"])

            player.team   = info_block_hash["teamId"].to_i
            player.squad  = info_block_hash["squadId"].to_i
            player.kills  = info_block_hash["kills"].to_i
            player.deaths = info_block_hash["deaths"].to_i
            player.score  = info_block_hash["score"].to_i
            player.rank   = info_block_hash["rank"].to_i

            player
        end

        attr_accessor :name, :guid, :score, :kills,
            :deaths, :rank

        def initialize(server, name, guid=NO_GUID)
            @server = server
            @name = name
            @guid = guid || NO_GUID

            @team_id = 0
            @squad_id = 0

            @kills = 0
            @deaths = 0
            @rank = 0
            @score = 0

            team.add self
            squad.add self
        end

        def update_from_info_block(info_block_hash)
            @team   = info_block_hash["teamId"].to_i
            @squad  = info_block_hash["squadId"].to_i
            @kills  = info_block_hash["kills"].to_i
            @deaths = info_block_hash["deaths"].to_i
            @score  = info_block_hash["score"].to_i
            @rank   = info_block_hash["rank"].to_i
        end

        def team
            @server.teams[@team_id]
        end

        def team=(new_team)
            if new_team.is_a?(Integer) && new_team.between?(0, 16)
                # removing from a team also removes from the squad
                return if @team_id == new_team
                team.remove self.name
                @team_id = new_team
                team.add self
                # adding to a team also adds to the squad
            elsif new_team.is_a? Team
                return if @team_id == new_team.id
                # TODO: make this issue a move command if a team object
                # is passed, as likely it will be done by a script
                team = new_team.id
            else
                raise "#{new_team} is not a valid team!"
            end
        end

        def squad
            @server.teams[@team_id].squads[@squad_id]
        end

        # Used by Team#add to move the player to the appropriate squad
        def squad_id
            @squad_id
        end

        def squad=(new_squad)
            if new_squad.is_a?(Integer) && new_squad.between?(0, 32)
                return if @squad_id == new_squad
                squad.remove self.name
                @squad_id = new_squad
                squad.add self
            elsif new_squad.is_a? Squad
                return if @squad_id == new_squad.id
                # TODO: make this issue a move command if a squad object
                # is passed, as likely it will be done by a script
                squad = new_squad.id
            else
                raise "#{new_squad} is not a valid squad!"
            end
        end

        # Says `msg` to a player's chatbox.
        def say(msg)
            @server.send_command("admin.say", msg, "player", @name)
        end

        # Yells `msg` to the player for `duration` seconds.
        def yell(msg, duration)
            @server.send_command("admin.yell", msg, duration, "player", @name)
        end

        # Kick a player. If a reason is not passed, it will default to the BF3 server's
        # default value of "Kicked by administrator."
        def kick(reason=nil) 
            server.kick_player @name, reason
        end

        # Kill the player.
        def kill
            @server.kill_player @name
        end

        # Called when the player leaves the server. It removes the player from the squad
        # and team they are currently in.
        def disconnected
            squad.remove @name
            team.remove @name
        end

        # Whether or not this player has permission `perm_name` on this server or globally.
        def has_permission?(perm_name)
            @server.permissions_manager.player_has_permission?(@name, perm_name)
        end

        # Whether or not the player belongs to `group_name` on this server or globally.
        def belongs_to_group?(group_name)
            @server.permissions_manager.player_belongs_to_group?(@name, group_name)
        end

        # This is relatively slow, especially for large amounts of players, but if
        # you're a masochist and want your plugin to be slow, feel free to use this.
        # It does not cache previous pings.
        def ping
            ping_packet = @server.send_request("player.ping", @name)
            if ping_packet.words[0] == "OK"
                ping_packet.words[1].to_i
            else
                -1
            end
        end

        def alive?
            alive_packet = @server.send_request("player.isAlive", @name)
            if ping_packet.read_word == "OK"
                ping_packet.read_bool
            else
                true
            end
        end

        # Should return true for actual humans who triggered the event.
        # Will return false if the event has generated by a machine, such as
        # the console or the game server itself.
        #
        # NOTE: This function cannot currently detect aimbots.
        def is_human?
            true
        end

        # Pretty print like a boss
        def inspect
            "#<BF3Player: #{@name} (#{@guid}) #{@kills}K:#{@deaths}D #{@score}>"
        end

        # Converts this player to a Hash. Useful for things like JSON serialization
        def to_hash
            {
                name:   @name,
                guid:   @guid, 
                team:   @team_id,
                squad:  @squad_id,
                kills:  @kills,
                deaths: @deaths,
                rank:   @rank,
                score:  @score
            }
        end
    end

    # A special player is used for any commands or events sent by the console or the
    # game server itself. It has every permission and returns `false` for `is_human?`
    class SpecialPlayer < Player
        def initialize(server, name, guid=NO_GUID)
            @server = server
            @name = name
            @guid = guid

            @team_id = 0
            @squad_id = 0

            @kills = 0
            @deaths = 0
            @rank = 0
            @score = 0
        end

        def has_permission?(perm)
            true
        end

        def is_human?
            return false
        end
    end
end