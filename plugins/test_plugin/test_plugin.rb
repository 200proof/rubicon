class MyTestPlugin < Rubicon::Plugin
    command "perm_test" do 
        if player.has_permission?("test")
            logger.info "#{player.name} perm :test"
        else
            logger.warn "#{player.name} CANNOT :test"
        end
    end

    command "group_test" do 
        if player.belongs_to_group?("test")
            logger.info "#{player.name} is in group \"test\""
        else
            logger.warn "#{player.name} is NOT in group \"test\""
        end
    end

    command "ping" do
        player = server.players[args[0]]
        if player
            p player.ping
        end
    end
end