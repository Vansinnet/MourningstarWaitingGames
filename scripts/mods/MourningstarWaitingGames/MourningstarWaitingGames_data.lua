local mod = get_mod("MourningstarWaitingGames")

return {
	name           = mod:localize("mod_name"),
	description    = mod:localize("mod_description"),
	is_togglable   = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id    = "enable_tetris",
				type          = "checkbox",
				default_value = true,
				tooltip       = "enable_tetris_tooltip",
			},
			{
				setting_id       = "game_toggle_key",
				type             = "keybind",
				default_value    = { "f11" },
				keybind_trigger  = "pressed",
				keybind_type     = "function_call",
				function_name    = "toggle_game",
				tooltip          = "game_toggle_key_tooltip",
			},
		},
	},
}
