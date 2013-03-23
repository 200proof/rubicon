class MyTestPlugin < Rubicon::Plugin
    command :shutdown do
        server.connection.close_connection
    end
end