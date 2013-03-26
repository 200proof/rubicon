# encoding: utf-8
class MyTestPlugin < Rubicon::Plugin
    command :rbcshutdown do
        logger.info "Shutdown issued by #{player.name}!"
        server.connection.close_connection
    end
end