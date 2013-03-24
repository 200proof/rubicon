class MyTestPlugin < Rubicon::Plugin
    event "player.onKill" do
        logger.info "#{killer.name} #{"(+)" if headshot?}[#{weapon.name}] #{victim.name}"
    end

    event "player.onSuicide" do
        logger.info "#{player.name} killed themselves via #{weapon.name}"
    end

    event "player.onJoin" do
        logger.info "#{player.name} has joined the server!"
    end

    command :rbcshutdown do
        logger.info "Shutdown issued by #{player.name}!"
        server.connection.close_connection
    end
end