-- Luacheck configuration for Yazi plugins
-- Yazi provides these globals in the plugin environment

globals = {
	"ya",
	"Command",
	"ps",
	"ui",
	"cx",
}

-- Don't report unused arguments (common in callbacks)
unused_args = false

-- Don't report unused variables that start with _
ignore = { "^_" }
