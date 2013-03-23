module Rubicon::Frostbite::BF3
    WEAPONS = {
        "Melee" => Weapon.new(:takedown),
        "Weapons/Knife/Knife" => Weapon.new(:regular_knife),
        "Knife_RazorBlade" => Weapon.new(:premium_knife),
        "Defib" => Weapon.new(:defibrillator),
        "EOD BOT" => Weapon.new(:eod_bot),
        "M15 AT Mine" => Weapon.new(:at_mine),
        "M67" => Weapon.new(:grenade),
        "MAV" => Weapon.new(:mav),
        "Repair Tool" => Weapon.new(:repair_tool),
        "Weapons/Gadgets/C4/C4" => Weapon.new(:c4),
        "Weapons/Gadgets/Claymore/Claymore" => Weapon.new(:claymore),
        "CrossBow" => Weapon.new(:crossbow),
        "M320" => Weapon.new(:grenade_launcher),
        "RPG-7" => Weapon.new(:rpg7),
        "SMAW" => Weapon.new(:smaw),
        "FGM-148" => Weapon.new(:javelin),
        "AEK-971" => Weapon.new(),
        "AKS-74u" => Weapon.new(),
        "AN-94 Abakan" => Weapon.new(),
        "FAMAS" => Weapon.new(),
        "G3A3" => Weapon.new(),
        "Weapons/G3A3/G3A3" => Weapon.new(),
        "G53" => Weapon.new(),
        "HK53" => Weapon.new(),
        "M16A4" => Weapon.new(),
        "M27IAR" => Weapon.new(),
        "M4A1" => Weapon.new(),
        "MG36" => Weapon.new(),
        "QBB-95" => Weapon.new(),
        "QBZ-95" => Weapon.new(),
        "RPK-74M" => Weapon.new(),
        "SG 553 LB" => Weapon.new(), # TODO: verify me
        "Weapons/A91/A91" => Weapon.new(),
        "Weapons/AK74M/AK74" => Weapon.new(),
        "Weapons/G36C/G36C" => Weapon.new(),
        "Weapons/KH2002/KH2002" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
        "" => Weapon.new(),
    }

    class Weapon
        def initialize(sym)
            @symbol = sym
        end

        def ==(other)
            if other == :knife
                return [:takedown, :regular_knife, :premium_knife].include? @sym
            elsif other == :rocket_launcher
                return [:rpg7, :smaw].include? @sym
            elsif other == :aa_missile
                return [:stinger, :igla].include? @sym
            else
                @sym == other
            end
        end

        def to_s
            FRIENDLY_NAMES[@sym]
        end
    end
end