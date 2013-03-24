module Rubicon::Frostbite::BF3
    class Weapon
        attr_reader :symbol
        def initialize(sym)
            @symbol = sym
        end

        def ==(other)
            if other == :knife
                return [:takedown, :regular_knife, :premium_knife].include? @symbol
            elsif other == :rocket_launcher
                return [:rpg7, :smaw].include? @symbol
            elsif other == :aa_missile
                return [:stinger, :igla].include? @symbol
            else
                @sym == other
            end
        end

        def to_s
            FRIENDLY_NAMES[@symbol]
        end

        alias name to_s
    end

    WEAPONS = {
        "Melee"                             => Weapon.new(:takedown),
        "Weapons/Knife/Knife"               => Weapon.new(:regular_knife),
        "Knife_RazorBlade"                  => Weapon.new(:premium_knife),
        "Defib"                             => Weapon.new(:defibrillator),
        "EOD BOT"                           => Weapon.new(:eod_bot),
        "M15 AT Mine"                       => Weapon.new(:at_mine),
        "M67"                               => Weapon.new(:grenade),
        "MAV"                               => Weapon.new(:mav),
        "Repair Tool"                       => Weapon.new(:repair_tool),
        "Weapons/Gadgets/C4/C4"             => Weapon.new(:c4),
        "Weapons/Gadgets/Claymore/Claymore" => Weapon.new(:claymore),
        "CrossBow"                          => Weapon.new(:crossbow),
        "M320"                              => Weapon.new(:grenade_launcher),
        "RPG-7"                             => Weapon.new(:rpg7),
        "SMAW"                              => Weapon.new(:smaw),
        "FGM-148"                           => Weapon.new(:javelin),
        "AEK-971"                           => Weapon.new(:aek971),
        "AKS-74u"                           => Weapon.new(:aks74u),
        "AN-94 Abakan"                      => Weapon.new(:an94),
        "FAMAS"                             => Weapon.new(:famas),
        "G3A3"                              => Weapon.new(:g3a3),
        "Weapons/G3A3/G3A3"                 => Weapon.new(:g3a3),
        "G53"                               => Weapon.new(:g53),
        "HK53"                              => Weapon.new(:g53),
        "M16A4"                             => Weapon.new(:m16),
        "M27IAR"                            => Weapon.new(:m27),
        "M4A1"                              => Weapon.new(:m4),
        "MG36"                              => Weapon.new(:mg36),
        "QBB-95"                            => Weapon.new(:qbb95),
        "QBZ-95"                            => Weapon.new(:qbz95),
        "RPK-74M"                           => Weapon.new(:rpk74m),
        "SG 553 LB"                         => Weapon.new(:sg553), # TODO: verify me
        "Weapons/A91/A91"                   => Weapon.new(:a91),
        "Weapons/AK74M/AK74"                => Weapon.new(:ak74),
        "Weapons/G36C/G36C"                 => Weapon.new(:g36),
        "Weapons/KH2002/KH2002"             => Weapon.new(:kh2002),
        "Weapons/M416/M416"                 => Weapon.new(:m416),
        "M416"                              => Weapon.new(:m416),
        "Weapons/SCAR-H/SCAR-H"             => Weapon.new(:scar_h),
        "Weapons/XP1_L85A2/L85A2"           => Weapon.new(:l85a2),
        "Steyr AUG"                         => Weapon.new(:aug),
        "Weapons/XP2_ACR/ACR"               => Weapon.new(:acr),
        "SCAR-L"                            => Weapon.new(:scar_l),
        "Weapons/XP2_MTAR/MTAR"             => Weapon.new(:mtar21),
        "L96"                               => Weapon.new(:l96),
        "M39"                               => Weapon.new(:m39),
        "M40A5"                             => Weapon.new(:m40a5),
        "Mk11"                              => Weapon.new(:mk11),
        "Model98B"                          => Weapon.new(:m98b),
        "QBU-88"                            => Weapon.new(:qbu88),
        "SKS"                               => Weapon.new(:sks),
        "SV98"                              => Weapon.new(:sv98),
        "SVD"                               => Weapon.new(:svd),
        "M417"                              => Weapon.new(:m417),
        "JNG90"                             => Weapon.new(:jng90),
        "870MCS"                            => Weapon.new(:r870mcs),
        "AS Val"                            => Weapon.new(:asval),
        "DAO-12"                            => Weapon.new(:dao12),
        "jackhammer"                        => Weapon.new(:mk3a1),
        "M1014"                             => Weapon.new(:m1014),
        "M26 MASS"                          => Weapon.new(:m26mass),
        "Siaga20k"                          => Weapon.new(:saiga), #todo: verify me
        "USAS-12"                           => Weapon.new(:usas12),
        "SPAS-12"                           => Weapon.new(:spas12),
        "F2000"                             => Weapon.new(:f2000),
        "Weapons/MagpulPDR/MagpulPDR"       => Weapon.new(:pdwr),
        "Weapons/P90/P90"                   => Weapon.new(:p90),
        "MP7"                               => Weapon.new(:mp7),
        "PP-19"                             => Weapon.new(:pp19),
        "PP-2000"                           => Weapon.new(:pp2000),
        "Weapons/UMP45/UMP45"               => Weapon.new(:ump45),
        "Weapons/XP2_MP5K/MP5K"             => Weapon.new(:mp5k),
        "M240"                              => Weapon.new(:m240),
        "M249"                              => Weapon.new(:m249),
        "M60"                               => Weapon.new(:m60),
        "M60E4"                             => Weapon.new(:m60),
        "Pecheneg"                          => Weapon.new(:pkp),
        "Type88"                            => Weapon.new(:type88),
        "Weapons/XP2_L86/L86"               => Weapon.new(:l86),
        "LSAT"                              => Weapon.new(:lsat),
        "Glock17"                           => Weapon.new(:g17),
        "Glock18"                           => Weapon.new(:g18),
        "M1911"                             => Weapon.new(:m1911),
        "M9"                                => Weapon.new(:m9),
        "M93R"                              => Weapon.new(:m93),
        "Taurus .44"                        => Weapon.new(:magnum44),
        "Weapons/MP412REX/MP412REX"         => Weapon.new(:mp412rex),
        "Weapons/MP443/MP443"               => Weapon.new(:mp443),
        "Death"                             => Weapon.new(:out_of_bounds),
        "Suicide"                           => Weapon.new(:suicide),
        "SoldierCollision"                  => Weapon.new(:pancakes), # no.. this will not be changed
        "\x89D$\x14\x85\xDBt\b\x8B\x83\x1C\x03" => Weapon.new(:bad_luck), # apparently....
    }

    WEAPONS.default_proc = proc do |hash, key|
        p key
    end

    FRIENDLY_NAMES = {
        takedown:           "Knife Takedown",
        regular_knife:      "Knife",
        premium_knife:      "ACB-90",
        defibrillator:      "Defibrillator",
        eod_bot:            "EOD Bot",
        at_mine:            "M15 AT Mine",
        grenade:            "M67 Grenade",
        mav:                "MAV",
        repair_tool:        "Repair Tool",
        c4:                 "C4 Explosives",
        claymore:           "M18 Claymore",
        crossbow:           "Crossbow",
        grenade_launcher:   "Grenade Launcher",
        rpg7:               "RPG-7",
        smaw:               "SMAW",
        javelin:            "FGM-148 Javelin",
        aek971:             "AEK-971",
        aks74u:             "AKS-74u",
        an94:               "AN-94",
        famas:              "FAMAS",
        g3a3:               "G3A3",
        g53:                "G53",
        m16:                "M16",
        m27:                "M27 IAR",
        m4:                 "M4A1",
        mg36:               "MG36",
        qbb95:              "QBB-95",
        qbz95:              "QBZ-95",
        rpk74m:             "RPK-74M",
        sg553:              "SG553",
        a91:                "A-91",
        ak74:               "AK-74M",
        g36:                "G36C",
        kh2002:             "KH2002",
        m416:               "M416",
        scar_h:             "SCAR-H",
        l85a2:              "L85A2",
        aug:                "AUG",
        acr:                "ACW-R",
        scar_l:             "SCAR-L",
        mtar21:             "MTAR-21",
        l96:                "L96",
        m39:                "M39 EMR",
        m40a5:              "M40A5",
        mk11:               "Mk. 11",
        m98b:               "M98B",
        qbu88:              "QBU-88",
        sks:                "SKS",
        sv98:               "SV98",
        svd:                "SVD",
        m417:               "M417",
        jng90:              "JNG-90",
        r870mcs:            "870MCS",
        asval:              "AS Val",
        dao12:              "DAO-12",
        mk3a1:              "MK3A1",
        m1014:              "M1014",
        m26mass:            "M26 MASS",
        saiga:              "Saiga 12K",
        usas12:             "USAS-12",
        spas12:             "SPAS-12",
        f2000:              "F2000",
        pdwr:               "PDW-R",
        p90:                "P90",
        mp7:                "MP7",
        pp19:               "PP-19",
        pp2000:             "PP-2000",
        ump45:              "UMP-45",
        mp5k:               "M5K",
        m240:               "M240",
        m249:               "M249",
        m60:                "M60E4",
        pkp:                "PKP Pecheneg",
        type88:             "Type 88",
        l86:                "L86",
        lsat:               "LSAT",
        g17:                "G17C",
        g18:                "G18",
        m1911:              "M1911",
        m9:                 "M9",
        m93:                "M93R",
        magnum44:           ".44 Magnum",
        mp412rex:           "MP412 REX",
        mp443:              "MP443",
        out_of_bounds:      "Out of Bounds", 
        suicide:            "Suicide",
        bad_luck:           "Bad Luck",
        pancakes:           "Terminal Deceleration" 
    }
end