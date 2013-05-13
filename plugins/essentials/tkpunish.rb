class TKPunish < Rubicon::Plugin
    enabled do
        # victim => [killers]
        @active_punishes = {}
        @active_punishes.default_proc = proc do |hash, key|
            hash[key] = []
        end

        @queued_punishes = []
    end

    disabled do
        @active_punishes, @queued_punishes = nil, nil
    end

    event "player.onKill" do
        victim_name = victim.name
        killer_name = killer.name

        if killer.team == victim.team
            @active_punishes[victim_name].push killer_name
            victim.say "You have been teamkilled by #{killer_name}. You may !punish or !forgive."
        end
    end

    event "player.onSpawn" do
        if @queued_punishes.include? player.name
            @queued_punishes.delete player.name
            player.kill
            server.say "#{player.name} has been punished for prior teamkilling."
        end
    end

    event "player.onLeave" do
        if @queued_punishes.include? player_name
            @queued_punishes.delete player_name
        end
    end

    command "punish"  do; punish;  end
    command "p"       do; punish;  end

    command "forgive" do; forgive; end
    command "f"       do; forgive; end

    def perform_or_queue_punish(killer, victim)
        if killer.alive?
            killer.kill
            server.say "#{killer.name} has been punished for team killing."
        else
            victim.say "#{killer.name} is dead and will be punished on their next spawn."
            @queued_punishes.push killer.name
        end
    end

    def punish
        victim      = player
        victim_name = player.name
        killer_name = @active_punishes[victim_name].pop

        if killer_name
            if killer = server.players[killer_name]
                if killer.has_permission? "tkpunish_exempt"
                    if victim.has_permission? "tkpunish_override"
                        perform_or_queue_punish killer, victim
                    else
                        server.say "You cannot punish #{killer_name} as they are immune from punishing."
                    end
                else
                    perform_or_queue_punish killer, victim
                end
            else
                player.say "You cannot punish #{killer_name} as they are no longer on the server."
            end
        end
    end

    def forgive
        victim_name = player.name
        killer_name = @active_punishes[victim_name].pop

        server.say "#{victim_name} forgave #{killer_name} for teamkilling." if killer_name 
    end
end
