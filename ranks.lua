return {
    _default = "stone",

    stone = {
        items = {
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
        --   overwrite = true
        --
        -- ["stone-2"] = {
        --     parent = "stone",
        --     items = {
        --         { id = "minecraft:diamond", label = "Diamante", default = 64 }, -- override
        --         { id = "minecraft:gold_ingot", label = "Ouro", default = 128 }, -- novo
        --     },
        -- },
    },

    iron = {
        items = {
            { id = "minecraft:copper_block",   label = "Bloco de Cobre",          default = 128 },
            { id = "minecraft:iron_block",     label = "Bloco de Ferro",          default = 64  },
            { id = "minecraft:redstone_block", label = "Bloco de Redstone",       default = 48  },
            { id = "minecraft:coal_block",     label = "Bloco de Carvao",         default = 96  },
            { id = "minecraft:lapis_block",    label = "Bloco de Lapis-Lazuli",   default = 48  },
            { id = "minecraft:quartz_block",   label = "Bloco de Quartzo",        default = 48  },
            { id = "minecraft:glass",          label = "Bloco de Vidro",          default = 256 },
            { id = "minecraft:calcite",        label = "Bloco de Calcita",        default = 256 },
            { id = "minecraft:andesite",       label = "Bloco de Andesito",       default = 512 },
            { id = "create:andesite_alloy",    label = "Create: Liga Andesito",   default = 256 },
            { id = "create:shaft",             label = "Create: Eixo",            default = 192 },
            { id = "create:cogwheel",          label = "Create: Engrenagem",      default = 96  },
            { id = "create:large_cogwheel",    label = "Create: Eng. Grande",     default = 48  },
            { id = "create:gearbox",           label = "Create: Caixa Eng.",      default = 24  },
            { id = "create:andesite_casing",   label = "Create: Casing Andesito", default = 24  },
            { id = "minecraft:emerald",        label = "Esmeralda",               default = 32  },
        },
    },
}
