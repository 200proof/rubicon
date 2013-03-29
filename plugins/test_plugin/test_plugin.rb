class MyTestPlugin < Rubicon::Plugin
    event "player.onKill" do
        logger.info "#{@current_args}"
    end
end