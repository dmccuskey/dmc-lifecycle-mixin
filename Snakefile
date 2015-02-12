# dmc-lifecycle-mixin

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-lifecycle-mixin"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-lifecycle-mixin",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_lifecycle_mix.lua"
		],
		"requires": [
			"dmc-corona-boot",
			"DMC-Lua-Library"
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}

register( "dmc-lifecycle-mixin", module_config )

