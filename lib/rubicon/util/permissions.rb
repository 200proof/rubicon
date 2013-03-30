require "set"

module Rubicon::Util
    class PermissionsManager
        def self.set_global_permissions(hash)
            @@global_permissions = PermissionsManager.new(hash, true)
        end

        def self.global_permissions
            @@global_permissions
        end

        def initialize(permissions_hash, is_global=false)
            # Sets are used instead of arrays to prevent duplication in case
            # a user or plugin adds a user/permission/group multiple
            # times

            # is_global is used to prevent infinite recursion when checking for
            # global permissions
            @is_global = is_global

            # groupname => [[users], [permissions]]
            @groups = {}
            @groups.default_proc = proc do |hash, key|
                hash[key] = [Set.new, Set.new]
            end

            # username => [[groups], [permissions]]
            @players = {}
            @players.default_proc = proc do |hash, key|
                hash[key] = [Set.new, Set.new]
            end

            load_permissions_from(permissions_hash)
        end

        def load_permissions_from(hash)
            hash["groups"] ||= {}
            hash["players"] ||= []

            hash["groups"].each do |name, permissions|
                @groups[name][1].merge permissions
            end

            hash["players"].each do |player_obj|
                player_name = player_obj["name"] || return
                groups = player_obj["groups"] || []
                perms = player_obj["permissions"] || []

                groups.each do |group_name|
                    add_player_to_group(player_name, group_name)
                end

                perms.each do |perm_name|
                    give_permission_to_player(player_name, perm_name)
                end
            end
        end

        def serialize_to_hash
            ret_hash = {
                "groups" => {},
                "players" => []
            }

            @groups.each do |name, struct|
                permissions = struct[1]

                # no point saving a group which has no permissions
                # which was likely created when testing for permissions
                next if permissions.empty?

                ret_hash["groups"][name] = permissions.to_a
            end

            @players.each do |name, struct|
                groups      = struct[0]
                permissions = struct[1]

                # same as above
                next if groups.empty? && permissions.empty?

                player_hash = {}
                player_hash["name"] = name

                # Don't put in redundant entries which will likely be serialized to YAML
                # and make it ugly
                player_hash["groups"] = groups.to_a unless groups.empty?
                player_hash["permissions"] = permissions.to_a unless permissions.empty?

                ret_hash["players"] << player_hash
            end

            ret_hash
        end

        def player_has_permission?(player_name, perm_name)
            player = @players[player_name]
            return true if player[1].include? (perm_name)

            player[0].each do |group_name|
                return true if group_has_permission?(group_name, perm_name)
            end

            # The unless is used to prevent infinite recursion, and only the global
            # permissions manager will hit the return false if it didn't hit
            # any of the `return true`s above
            return @@global_permissions.player_has_permission?(player_name, perm_name) unless @is_global
            return false
        end

        def group_has_permission?(group_name, perm_name)
            has_perm = @groups[group_name][1].include?(perm_name) 

            return has_perm if @is_global
            @@global_permissions.group_has_permission?(group_name, perm_name)
        end

        def player_belongs_to_group?(player_name, group_name)
            does_belong = @groups[group_name][0].include?(player_name)

            return does_belong if @is_global
            @@global_permissions.player_belongs_to_group?(player_name, group_name)
        end

        def add_player_to_group(player_name, group_name)
            @players[player_name][0] << group_name
            @groups[group_name][0] << player_name
        end

        def remove_player_from_group(player_name, group_name)
            @players[player_name][0].delete group_name
            @groups[group_name][0].delete player_name
        end

        def give_permission_to_player(player_name, perm_name)
            @players[player_name][1] << perm_name
        end

        def give_permission_to_group(group_name, perm_name)
            @groups[group_name][1] << perm_name
        end

        def revoke_permission_from_player(player_name, perm_name)
            @players[player_name][1].delete perm_name
        end

        def revoke_permission_from_group(group_name, perm_name)
            @groups[group_name][1].delete perm_name
        end
    end
end