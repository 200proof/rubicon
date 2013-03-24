class MyTestPlugin < Rubicon::Plugin
    event "player.onKill" do
        logger.info "[KILL] #{killer.name} #{"(+)" if headshot?}[#{weapon.name}] #{victim.name}"
    end

    event "player.onSuicide" do
        logger.info "[SCDE] #{player.name} killed themselves via #{weapon.name}"
    end

    command :rbcshutdown do
        logger.info "Shutdown issued by #{player.name}!"
        server.connection.close_connection
    end
end