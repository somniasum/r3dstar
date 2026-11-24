-- hyprland.lua: DedSec setup for coding, binary exploitation and gaming, tuned for low overhead.
-- Needs Hyprland 0.55+ (Lua config). Check errors with: hyprctl configerrors

----------------
---- COLORS ----
----------------
-- Match C_ACC from dwm/config.h if your red differs.
local RED = "rgba(ff2a2aff)"
local MAGENTA = "rgba(ff0a78ff)" -- second stop of the border glow
local INACTIVE = "rgba(1c1c1cff)"

-- Animations cost GPU time on every window open, close and workspace switch, so the lean
-- default is none. true = short snappy ones (Super+F10 game mode switches them off either way).
local ANIMATIONS = true

------------------
---- PROGRAMS ----
------------------
local terminal = "ghostty"
local browser = "brave-origin"
local launcher = "fuzzel"
local scripts = "~/.config/hypr/scripts"

----------------
---- MONITORS ----
----------------
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
	hl.exec_cmd(scripts .. "/wallpaper")
	hl.exec_cmd("waybar")
	hl.exec_cmd("mako")
	hl.exec_cmd(scripts .. "/idle") -- lock after 15 min idle (needs swayidle + swaylock)
	-- clipboard history (text only), skipped if cliphist is not installed
	hl.exec_cmd("command -v cliphist >/dev/null && wl-paste --type text --watch cliphist store")
end)

-----------
---- ENV ----
-----------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "iHD") -- Intel iHD: hardware video decode in mpv/browsers
hl.env("mesa_glthread", "true") -- threaded OpenGL in Mesa, helps older OpenGL games
hl.env("MESA_SHADER_CACHE_MAX_SIZE", "4G") -- default is 1G; a bigger cache means fewer shader-compile stutters across many games
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1") -- fixes blank Java windows (Ghidra, Burp)

-------------------------------
---- LOOK: DedSec, no blur ----
-------------------------------
hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 6,
		border_size = 2,
		col = {
			active_border = { colors = { RED, MAGENTA }, angle = 45 },
			inactive_border = INACTIVE,
		},
		resize_on_border = false,
		allow_tearing = true, -- used by the game rule below
		layout = "master", -- dwm-style: one master, stack on the side
	},

	decoration = {
		rounding = 0, -- sharp corners, HUD style
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = { enabled = false },
		blur = { enabled = false },
	},

	animations = { enabled = ANIMATIONS },
})

hl.config({
	master = {
		new_status = "master", -- new windows become master, like dwm
		mfact = 0.55,
	},
})

-- Fast, cheap animations: windows pop in, workspaces fade. No blur, no shadows.
if ANIMATIONS then
	hl.curve("snap", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

	hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "snap" })
	hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "snap", style = "popin 92%" })
	hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "snap", style = "popin 92%" })
	hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "snap" })
	hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "snap" })
	hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "snap", style = "fade" })
end

---------------------
---- PERFORMANCE ----
---------------------
hl.config({
	render = {
		-- Scan out fullscreen games directly (2 = only for games).
		-- If a native-Wayland game goes black in fullscreen, set this to 0.
		direct_scanout = 2,

		-- Switches to triple buffering when the GPU can't keep up. Helps weak
		-- iGPUs a lot, costs nothing when the GPU is coping. Experimental.
		new_render_scheduling = true,

		-- Turns off the colour-management pipeline (HDR / ICC profiles), which is extra GPU
		-- work per frame on an SDR screen. Needs a log out and in to fully apply. Remove this
		-- line if you want HDR.
		cm_enabled = false,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		vrr = 0,
		enable_anr_dialog = false,
	},

	-- vfr lives in "debug" since 0.55 (it is on by default; this just pins it)
	debug = {
		vfr = true,
	},

	ecosystem = {
		no_update_news = true,
		no_donation_nag = true,
	},

	xwayland = {
		force_zero_scaling = true,
	},

	cursor = {
		inactive_timeout = 3, -- hide the cursor after 3s of no movement
	},

	binds = {
		hide_special_on_workspace_change = true, -- scratchpads close when you switch workspace
	},
})

-------------
---- INPUT ----
-------------
hl.config({
	input = {
		kb_layout = "us", -- change if your layout differs
		follow_mouse = 1,
		sensitivity = 0,
		accel_profile = "flat", -- no mouse acceleration, better for games
		repeat_rate = 35,
		repeat_delay = 250,
		numlock_by_default = true,
	},
})

---------------------
---- KEYBINDINGS ----
---------------------
-- Every bind has a description. Super+/ shows them all (the list comes from Hyprland itself).
local mod = "SUPER"

local function bind(keys, dsp, desc, opts)
	opts = opts or {}
	if desc and desc ~= "" then
		opts.description = desc
	end
	hl.bind(keys, dsp, opts)
end

local function run(keys, cmd, desc, opts)
	bind(mod .. " + " .. keys, hl.dsp.exec_cmd(cmd), desc, opts)
end

-- Apps
run("Return", terminal, "Terminal")
run("w", browser, "Browser")
run("d", launcher, "App launcher")
run("SHIFT + d", scripts .. "/runner", "Run any command")
run("Escape", scripts .. "/powermenu", "Power menu (lock, logout, reboot...)")
run("slash", scripts .. "/keys", "Keybind cheat sheet")
run("CTRL + l", scripts .. "/lock", "Lock screen")

-- Scratchpads: drop-down windows that appear over whatever you are doing.
-- Press again to hide. The window is started on first use.
run("grave", scripts .. "/scratch scratch", "Scratchpad terminal")
run("n", scripts .. "/scratch notes " .. scripts .. "/notes", "Scratchpad notes (current CTF box or ~/notes.md)")
run("c", scripts .. "/scratch calc python3 -i " .. scripts .. "/calc.py", "Scratchpad hex/endian REPL")

-- Clipboard history and LHOST (your VPN IP, for reverse shells)
run("v", scripts .. "/clip", "Clipboard history")
run("SHIFT + v", scripts .. "/clip wipe", "Wipe clipboard history")
run("SHIFT + i", scripts .. "/lhost", "Copy my VPN IP (LHOST)")

-- Screenshots
bind("Print", hl.dsp.exec_cmd(scripts .. "/shot area"), "Screenshot: area")
bind("SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/shot full"), "Screenshot: full screen")
run("Print", scripts .. "/shot window", "Screenshot: window")
run("s", scripts .. "/shot area", "Screenshot: area")
run("SHIFT + s", scripts .. "/shot full", "Screenshot: full screen")
run("SHIFT + o", scripts .. "/shot ocr", "OCR: copy text from the screen")

-- Volume and media (Super+F1..F7, plus the dedicated keys)
local vol_up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
local vol_down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
local mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
local mic = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

run("F1", mute, "Mute")
run("F2", vol_down, "Volume down", { repeating = true })
run("F3", vol_up, "Volume up", { repeating = true })
run("F4", mic, "Mute microphone")
run("F5", "playerctl previous", "Previous track")
run("F6", "playerctl play-pause", "Play / pause")
run("F7", "playerctl next", "Next track")

bind("XF86AudioMute", hl.dsp.exec_cmd(mute), "Mute", { locked = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(vol_down), "Volume down", { locked = true, repeating = true })
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(vol_up), "Volume up", { locked = true, repeating = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd(mic), "Mute microphone", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous track", { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play / pause", { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Play / pause", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next track", { locked = true })

-- Windows
bind(mod .. " + q", hl.dsp.window.close(), "Close window")
bind(mod .. " + SHIFT + q", hl.dsp.exit(), "Quit Hyprland")
bind(mod .. " + j", hl.dsp.layout("cyclenext"), "Focus next window")
bind(mod .. " + k", hl.dsp.layout("cycleprev"), "Focus previous window")
bind(mod .. " + SHIFT + j", hl.dsp.layout("swapnext"), "Move window down the stack")
bind(mod .. " + SHIFT + k", hl.dsp.layout("swapprev"), "Move window up the stack")
bind(mod .. " + h", hl.dsp.layout("mfact -0.05"), "Shrink master area")
bind(mod .. " + l", hl.dsp.layout("mfact +0.05"), "Grow master area")
bind(mod .. " + i", hl.dsp.layout("addmaster"), "More windows in master")
bind(mod .. " + o", hl.dsp.layout("removemaster"), "Fewer windows in master")
bind(mod .. " + space", hl.dsp.layout("swapwithmaster master"), "Promote window to master")
bind(mod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + p", hl.dsp.window.pin({ action = "toggle" }), "Pin floating window to all workspaces")
bind(mod .. " + m", hl.dsp.window.fullscreen({ mode = "maximized" }), "Monocle (maximize, keeps the bar)")
bind(mod .. " + f", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Real fullscreen")

-- Bar and config
run("b", "pkill -SIGUSR1 waybar", "Hide / show the bar")
run("SHIFT + r", "hyprctl reload", "Reload the config")

-- Game mode (Super+F10): animations off, bar stopped, notifications silenced, idle lock paused,
-- performance power profile. Press again to bring everything back.
local game_mode = false
bind(mod .. " + F10", function()
	game_mode = not game_mode
	hl.config({ animations = { enabled = (not game_mode) and ANIMATIONS } })
	hl.exec_cmd(scripts .. (game_mode and "/game on" or "/game off"))
end, "Game mode on / off")

-- Workspaces 1-9 (dwm tags). Only the first of each row is listed in the cheat sheet.
for i = 1, 9 do
	bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), i == 1 and "Go to workspace 1-9 (Super+1..9)" or "")
	bind(
		mod .. " + SHIFT + " .. i,
		hl.dsp.window.move({ workspace = i }),
		i == 1 and "Move window to workspace 1-9 (Super+Shift+1..9)" or ""
	)
end
bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }), "Previous workspace")

-- Mouse: Super + left drag = move, Super + right drag = resize
bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window (drag)", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window (drag)", { mouse = true })

------------------------------
---- WORKSPACES AND GAPS ----
------------------------------
-- No gaps when a workspace has a single window (more screen for code and games)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

-------------
---- RULES ----
-------------
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Scratchpad windows (started by scripts/scratch) live in their own special workspace
local function scratch_rule(name, w, h)
	hl.window_rule({
		name = "scratch-" .. name,
		match = { class = "^com\\.dedsec\\." .. name .. "$" },
		workspace = "special:" .. name,
		float = true,
		size = { "monitor_w * " .. w, "monitor_h * " .. h },
		center = true,
	})
end
scratch_rule("scratch", 0.8, 0.6)
scratch_rule("notes", 0.6, 0.7)
scratch_rule("calc", 0.5, 0.5)
scratch_rule("btop", 0.85, 0.8) -- opened by clicking CPU or RAM in the bar

-- RE workspace layout: Ghidra on 4, Burp on 5. Check class names with: hyprctl clients
hl.window_rule({ name = "ghidra", match = { class = "(?i)^ghidra" }, workspace = "4" })
hl.window_rule({ name = "burp", match = { class = "(?i)^burp" }, workspace = "5" })

-- Games: tearing for the lowest input lag, no animations or shadows, workspace 9
hl.window_rule({
	name = "games",
	match = { class = "^(steam_app_.*|gamescope)$" },
	immediate = true,
	no_anim = true,
	no_shadow = true,
	workspace = "9",
})

-- Steam client on 9, its small windows float instead of tiling next to your game
hl.window_rule({ name = "steam", match = { class = "^steam$" }, workspace = "9" })
hl.window_rule({
	name = "steam-small-windows",
	match = { class = "^steam$", title = "^(Friends List|Steam Settings)$" },
	float = true,
})

-- A fullscreen window (game, video) keeps the screen awake: no idle lock while it is up
hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

-- Launcher, bar and notifications appear instantly
hl.layer_rule({
	name = "no-anim-ui",
	match = { namespace = "^(launcher|waybar|notifications)$" },
	no_anim = true,
})
