class Essentials < Rubicon::Plugin
    enabled do 
        @active_confirmations = {}
    end

    disabled do
        @active_confirmations = nil
    end

    command "kill" do
        if player.has_permission? "kill"
            entered_name = args.shift
            match_name(entered_name) do |name|
                server.kill_player(name)
                server.say("Killing #{name}.")
                logger.info("#{player.name} has admin killed #{name}")
            end
        else
            player.say "You do no have permission to kill players."
        end
    end

    command "kick" do
        if player.has_permission? "kick"
            entered_name = args.shift

            match_name(entered_name, args.join(" ")) do |name, reason|
                server.kick_player(name, reason)
                reason_str = (reason == "" ? "<no reason given>" : reason)
                server.say("Kicking #{name}: #{reason_str}")
                logger.info("#{player.name} has kicked #{name}: #{reason_str}")
            end
        else
            player.say("You do not have permission to kick players.")
        end
    end

    command "say" do
        if player.has_permission? "say"
            message = args.join(" ")

            server.say(message)
            logger.info("#{player.name} <admin chat>: #{message}")
        else
            player.say("You do not have permission to chat as an admin.")
        end
    end

    command "yell" do
        if player.has_permission? "yell"
            message = args.join(" ")
            server.yell(message)
            logger.info("#{player.name} <admin yell>: #{message}")
        else
            player.say("You do not have permission to yell.")
        end
    end

    command "raw" do
        if player.has_permission? "raw"
            player.say(server.send_request(*args).inspect)
        else
            player.say "You do not have permission to execute raw commands"
        end
    end

    command "yes" do
        if confirmation_params = @active_confirmations[player.name]
            confirmation_params[0].call(*confirmation_params[1])
        end
    end

    command "no" do
        if @active_confirmations[player.name]
            @active_confirmations.delete(player.name)
        end
    end

    # Bans a player from the server by GUID
    command "ban" do
        if player.has_permission? "ban"
            name = args.shift

            match_name(name, *args) do |matched_name, *args|
                guid = server.players[matched_name].guid

                valid_timeout_given, timeout_args = try_parsing_timeout(args[0])
                args.shift if valid_timeout_given

                reason = args.join(" ")
                reason_str = (reason == "" ? "<no reason given>" : reason)

                reason.prepend("(#{matched_name}) ")
                server.ban_player(:guid, guid, reason, *timeout_args)
                server.say("Banning #{matched_name}: #{reason_str}")
                logger.info("#{player.name} banned #{matched_name} by GUID for #{timeout_args}: #{reason_str}")
            end
        else
            player.say("You do not have permission to ban players.")
        end
    end

    # Bans a player from the server by name
    command "nban" do
        if player.has_permission? "ban"
            name = args.shift

            match_name(name, *args) do |matched_name, *args|
                valid_timeout_given, timeout_args = try_parsing_timeout(args[0])
                args.shift if valid_timeout_given

                reason = args.join(" ")
                reason_str = (reason == "" ? "<no reason given>" : reason)

                server.ban_player(:name, matched_name, reason, *timeout_args)
                server.say("Banning #{matched_name}: #{reason_str}")
                logger.info("#{player.name} banned #{matched_name} by name for #{timeout_args}: #{reason_str}")
            end
        else
            player.say("You do not have permission to ban players.")
        end
    end

    def try_parsing_timeout(string)
        valid_timeout_given = false
        timeout             = 0

        string.scan /([0-9]+)([A-z])/ do |match|
            valid_timeout_given = true
            factor, multiplier  = match
            factor              = factor.to_i

            case(multiplier)
            when 'w'
                timeout += (factor * 604800)
            when 'd'
                timeout += (factor * 86400)
            when 'h'
                timeout += (factor * 3600)
            when 'm'
                timeout += (factor * 60)
            when 'r'
                return [true, [:rounds, factor]]
            else
                return [false, [:perm, 0]]
            end
        end

        return [valid_timeout_given, [:seconds, timeout]]
    end

    # Adapted from C# example at http://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
    def damerau_levenshtein(src, dest)
        if src.length == 0
            if dest.length == 0
                return 0
            else
                return dest.length
            end
        elsif dest.length == 0
            return src.length
        end

        scores       = Array.new(src.length + 2) { Array.new(dest.length + 2, 0) }
        worst_score  = src.length + dest.length
        scores[0][0] = worst_score
        sd           = {}

        for idx in (0..src.length)
            scores[idx + 1][0] = worst_score
            scores[idx + 1][1] = idx
        end

        for idx in (0..dest.length)
            scores[0][idx + 1] = worst_score
            scores[1][idx + 1] = idx
        end

        (src + dest).each_char do |chr|
            sd[chr] = 0
        end

        for i in (1..src.length)
            db = 0
            for j in (1..dest.length)
                i1 = sd[dest[j - 1]]
                j1 = db

                if src[i-1] == dest[j-1]
                    scores[i+1][j+1] = scores[i][j]
                else
                    scores[i+1][j+1] = [
                        scores[i]  [j], 
                        scores[i+1][j],
                        scores[i]  [j+1]
                    ].min + 1
                end

                scores[i+1][j+1] = [
                    scores[i+1][j+1],
                    (
                        scores[i1][j1] +
                        (i - i1 - 1) + 1 +
                        (j - j1 - 1)
                    )
                ].min
            end

            sd[src[i-1]] = i
        end

        scores[src.length + 1][dest.length + 1]
    end

    # Asks the player to confirm before executing `block`.
    def confirm(message, *args, &block)
        player.say(message)
        @active_confirmations[player.name] = [block, args]
    end

    # Tries to match `name` to a player in the server.
    # If a name is confidently found, it runs `block`, otherwise
    # it asks the player to confirm their command before running `block`
    def match_name(name, *args, &block)
        target     = name.downcase
        all_names  = server.players.keys

        candidates = all_names.reduce([]) do |ret, curr|
            ret << curr if curr.downcase.start_with? target
            ret
        end

        if candidates.length != 0
            substr_candidate = candidates.first

            if candidates.length == 1
                block.call(substr_candidate, *args)
            else
                confirm("Did you mean #{substr_candidate}?", substr_candidate, *args, &block)
            end
        else
            dl_scores = []
            all_names.each do |name|
                dl_scores << [name, damerau_levenshtein(target, name[0, target.length].downcase)]
            end
            dl_scores.sort! { |a, b| a[1] <=> b[1] }

            dl_candidate = dl_scores.first[0]
            confirm("Did you mean #{dl_candidate}?", dl_candidate, *args, &block)
        end
    end
end