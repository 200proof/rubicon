class MyTestPlugin < Rubicon::Plugin
    event "player.onKill" do
        logger.info "#{killer.name} #{"(+)" if headshot?}[#{weapon.name}] #{victim.name}"
    end

    command :rbcshutdown do
        logger.info "Shutdown issued by #{player.name}!"
        server.connection.close_connection
    end
end