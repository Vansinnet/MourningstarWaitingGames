return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MourningstarWaitingGames` encountered an error loading the Darktide Mod Framework.")

		new_mod("MourningstarWaitingGames", {
			mod_script       = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames",
			mod_data         = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_data",
			mod_localization = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_localization",
		})
	end,
	packages = {},
}
