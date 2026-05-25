return {
    refreshInterval  = 1,
    monitorTextScale = 0.5,
    energyUnit       = "FE",

    colors = {
        bg    = colors.black,
        title = colors.cyan,
        label = colors.lightGray,
        value = colors.white,
        good  = colors.lime,
        warn  = colors.yellow,
        bad   = colors.red,
        barBg = colors.gray,
    },

    cubeLabels = {
    },

    detectorLabels = {
    },

    itemListMode   = "flow",
    itemListLimit  = 5,
    itemListWindow = 600,

    rankupOutput  = "minecraft:chest_0",
    rankupTimeout = 300,
    rankupItems = {
        { id = "minecraft:stone",         label = "Pedra",              default = 1536 },
        { id = "minecraft:cobblestone",   label = "Pedregulho",         default = 1536 },
        { id = "minecraft:oak_log",       label = "Troncos",            default = 384  },
        { id = "minecraft:oak_planks",    label = "Tabuas",             default = 768  },
        { id = "minecraft:coal_block",    label = "Bloco de Carvao",    default = 144  },
        { id = "minecraft:glass",         label = "Vidro",              default = 384  },
        { id = "minecraft:iron_ingot",    label = "Ferro (lingote)",    default = 384  },
        { id = "minecraft:dirt",          label = "Bloco de Terra",     default = 512  },
        { id = "minecraft:sand",          label = "Bloco de Areia",     default = 512  },
        { id = "minecraft:gravel",        label = "Bloco de Cascalho",  default = 512  },
        { id = "minecraft:torch",         label = "Tocha",              default = 768  },
        { id = "minecraft:chest",         label = "Bau",                default = 64   },
        { id = "minecraft:furnace",       label = "Forno",              default = 32   },
        { id = "minecraft:hopper",        label = "Funil",              default = 32   },
        { id = "minecraft:rail",          label = "Trilho",             default = 384  },
        { id = "minecraft:white_wool",    label = "Bloco de La",        default = 384  },
        { id = "minecraft:book",          label = "Livro",              default = 96   },
        { id = "minecraft:diamond",       label = "Diamante",           default = 32   },
    },
}
