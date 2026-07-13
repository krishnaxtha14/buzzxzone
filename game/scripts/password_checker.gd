extends Control

var bad_words = ["password", "123456", "qwerty", "alex", "letmein",
				"welcome", "dragon", "monkey", "master", "admin",
				"iloveyou", "sunshine", "princess", "football", "abc123",
				"trustno1", "superman", "batman", "liverpool", "chelsea"]

var rounds = [
	{
		"account": "Instagram",
		"color": "#C13584",
		"icon": "📸",
		"story": "Alex's Instagram password was 'alex2010'. A hacker cracked it in 0.003 seconds using a simple dictionary attack!\n\nYour username + birth year = one of the first things hackers try.",
		"tip": "Tip: Use a passphrase — 3 random words + symbols + numbers. Example: Coffee!Star42Moon"
	},
	{
		"account": "Email Account",
		"color": "#378ADD",
		"icon": "📧",
		"story": "Alex's email used 'password123' — ranked the #1 most-breached password globally for 5 years in a row.\n\nEmail is the master key to ALL your accounts — if it's hacked, scammers can reset everything else.",
		"tip": "Tip: Your email password should be your STRONGEST and completely unique — never reused."
	},
	{
		"account": "Online Banking",
		"color": "#1D9E75",
		"icon": "🏦",
		"story": "Alex wants to set up online banking. Banks enforce strict password policies for a reason — financial data is the #1 target for cybercriminals.\n\nA weak banking password can cost you everything.",
		"tip": "Tip: Use a password manager (like Bitwarden or 1Password) to generate and store truly random strong passwords."
	}
]

var current_round = 0
var can_proceed  = false

func _ready():
	StyleManager.style_scene(self, "#EF9F27")
	StyleManager.add_back_button(self)
	StyleManager.make_alex(self, 820, 140, "worried")
	_style_ui()
	load_round()
	$VBoxContainer/PwInput.text_changed.connect(_on_password_changed)
	$VBoxContainer/ProceedBtn.pressed.connect(_on_proceed)
	$VBoxContainer/ProceedBtn.disabled = true
	call_deferred("_focus_input")

func _focus_input():
	$VBoxContainer/PwInput.grab_focus()

func _style_ui():
	$ColorRect.color = Color("#0D1B2A")
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$VBoxContainer/Label.add_theme_font_size_override("font_size", 28)
	$VBoxContainer/Label.add_theme_color_override("font_color", Color("#FFFFFF"))

	$VBoxContainer/Label2.add_theme_font_size_override("font_size", 16)
	$VBoxContainer/Label2.add_theme_color_override("font_color", Color("#85B7EB"))

	$VBoxContainer/HintLabel.add_theme_font_size_override("font_size", 15)
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	$VBoxContainer/HintLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/HintLabel.custom_minimum_size = Vector2(0, 150)

	$VBoxContainer/ScoreLabel.add_theme_font_size_override("font_size", 17)
	$VBoxContainer/ScoreLabel.add_theme_color_override("font_color", Color("#85B7EB"))

	# Password input styling
	var pw_style = StyleBoxFlat.new()
	pw_style.bg_color = Color("#0A1828")
	pw_style.border_color = Color("#1E3A5F")
	pw_style.set_border_width_all(2)
	pw_style.set_corner_radius_all(8)
	pw_style.content_margin_left = 14; pw_style.content_margin_right  = 14
	pw_style.content_margin_top  = 10; pw_style.content_margin_bottom = 10
	$VBoxContainer/PwInput.add_theme_stylebox_override("normal", pw_style)
	$VBoxContainer/PwInput.add_theme_stylebox_override("focus",  pw_style)
	$VBoxContainer/PwInput.add_theme_font_size_override("font_size", 20)
	$VBoxContainer/PwInput.add_theme_color_override("font_color",            Color("#FFFFFF"))
	$VBoxContainer/PwInput.add_theme_color_override("font_placeholder_color", Color("#4A6B8A"))
	$VBoxContainer/PwInput.custom_minimum_size = Vector2(520, 52)
	$VBoxContainer/PwInput.mouse_filter = Control.MOUSE_FILTER_STOP
	$VBoxContainer/PwInput.editable = true
	$VBoxContainer/PwInput.secret   = true

	$VBoxContainer/StrLabel.add_theme_font_size_override("font_size", 16)
	$VBoxContainer/StrLabel.add_theme_color_override("font_color", Color("#4A6B8A"))

	for seg in [$VBoxContainer/StrBar/Seg1, $VBoxContainer/StrBar/Seg2,
				$VBoxContainer/StrBar/Seg3, $VBoxContainer/StrBar/Seg4, $VBoxContainer/StrBar/Seg5]:
		seg.color = Color("#1E3A5F")

	$VBoxContainer/PadlockLabel.add_theme_font_size_override("font_size", 18)
	$VBoxContainer/PadlockLabel.add_theme_color_override("font_color", Color("#E24B4A"))

	StyleManager.style_button($VBoxContainer/ProceedBtn, "#185FA5", "#FFFFFF")
	$VBoxContainer/ProceedBtn.custom_minimum_size = Vector2(340, 58)

func load_round():
	var rd = rounds[current_round]
	$VBoxContainer/PwInput.text = ""
	$VBoxContainer/PwInput.placeholder_text = "Type a strong password for " + rd["account"] + "..."
	$VBoxContainer/ProceedBtn.disabled = true
	can_proceed = false

	$VBoxContainer/Label.text  = rd["icon"] + "  Mission 2 — Round " + str(current_round + 1) + " of 3"
	$VBoxContainer/Label2.text = "Securing Alex's " + rd["account"]

	$VBoxContainer/HintLabel.text = rd["story"] + "\n\n" + rd["tip"] + "\n\nBuild a strong password below:"
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))

	for seg in [$VBoxContainer/StrBar/Seg1, $VBoxContainer/StrBar/Seg2,
				$VBoxContainer/StrBar/Seg3, $VBoxContainer/StrBar/Seg4, $VBoxContainer/StrBar/Seg5]:
		seg.color = Color("#1E3A5F")

	$VBoxContainer/StrLabel.text = "Strength: Enter a password above"
	$VBoxContainer/StrLabel.add_theme_color_override("font_color", Color("#4A6B8A"))
	$VBoxContainer/PadlockLabel.text = "🔓 UNLOCKED — Password too weak"
	$VBoxContainer/PadlockLabel.add_theme_color_override("font_color", Color("#E24B4A"))
	$VBoxContainer/ProceedBtn.text = "Strengthen password first"
	_update_score_display()
	call_deferred("_focus_input")

func _on_password_changed(text: String):
	var has_length = text.length() >= 8
	var has_upper  = text != text.to_lower()
	var has_number = false
	for c in "0123456789":
		if c in text: has_number = true; break
	var has_symbol = false
	for c in "!@#$%^&*()_+-=[]{}|;:,.<>?":
		if c in text: has_symbol = true; break
	var no_common = text.length() > 0
	for word in bad_words:
		if word in text.to_lower(): no_common = false; break

	var strength = 0
	if has_length: strength += 1
	if has_upper:  strength += 1
	if has_number: strength += 1
	if has_symbol: strength += 1
	if no_common and text.length() > 0: strength += 1

	var segs    = [$VBoxContainer/StrBar/Seg1, $VBoxContainer/StrBar/Seg2,
				   $VBoxContainer/StrBar/Seg3, $VBoxContainer/StrBar/Seg4, $VBoxContainer/StrBar/Seg5]
	var colours = ["#E24B4A", "#E24B4A", "#EF9F27", "#EF9F27", "#1D9E75"]
	for i in range(5):
		segs[i].color = Color(colours[min(strength - 1, 4)]) if i < strength else Color("#1E3A5F")

	if text.length() == 0:
		$VBoxContainer/StrLabel.text = "Strength: Enter a password above"
		$VBoxContainer/StrLabel.add_theme_color_override("font_color", Color("#4A6B8A"))
	else:
		var str_labels = ["", "Very weak — hackable in seconds", "Weak — try harder!", "Getting better", "Almost strong enough", "Strong — well done!"]
		$VBoxContainer/StrLabel.text = "Strength: " + str_labels[strength]
		var col = Color("#E24B4A") if strength <= 2 else Color("#EF9F27") if strength <= 4 else Color("#1D9E75")
		$VBoxContainer/StrLabel.add_theme_color_override("font_color", col)

	# Live checklist
	var hint = "REQUIREMENTS:\n"
	hint += ("✅" if has_length else "❌") + "  8 or more characters\n"
	hint += ("✅" if has_upper  else "❌") + "  At least one UPPERCASE letter\n"
	hint += ("✅" if has_number else "❌") + "  At least one number (0–9)\n"
	hint += ("✅" if has_symbol else "❌") + "  At least one symbol  ! @ # $ %\n"
	hint += ("✅" if (no_common and text.length() > 0) else "❌") + "  No common/obvious words"
	$VBoxContainer/HintLabel.text = hint
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#CCDDEE"))

	if strength >= 5:
		$VBoxContainer/PadlockLabel.text = "🔒 LOCKED — " + rounds[current_round]["account"] + " secured!"
		$VBoxContainer/PadlockLabel.add_theme_color_override("font_color", Color("#1D9E75"))
		$VBoxContainer/ProceedBtn.disabled = false
		$VBoxContainer/ProceedBtn.text = "Round " + str(current_round + 2) + " — Next Account →" if current_round < 2 \
			else "Mission 2 Complete — Continue ✓"
		can_proceed = true
		StyleManager.spawn_correct_particles(self, Vector2(520, 480))
	else:
		$VBoxContainer/PadlockLabel.text = "🔓 UNLOCKED — Keep improving!"
		$VBoxContainer/PadlockLabel.add_theme_color_override("font_color", Color("#E24B4A"))
		$VBoxContainer/ProceedBtn.disabled = true
		$VBoxContainer/ProceedBtn.text = "Strengthen password first"
		can_proceed = false

func _update_score_display():
	var combo_txt = ""
	if GameManager.combo_streak >= 3:
		combo_txt = "  🔥 Combo x" + str(snappedf(GameManager.combo_mult, 0.5)).trim_suffix(".0") + "!"
	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + \
		"   ❤ " + str(GameManager.lives) + "   Round " + str(current_round + 1) + "/3" + combo_txt

func _on_proceed():
	if not can_proceed: return
	var pts = GameManager.add_score(10)
	StyleManager.screen_flash(self, Color("#1D9E75"))
	current_round += 1
	if current_round >= rounds.size():
		GameManager.complete_mission(2)
		var m2_score = GameManager.mission_scores.get(2, 0)
		$VBoxContainer/HintLabel.text = "🎉 MISSION 2 COMPLETE!\nAll three accounts are now secure!\nMission Score: +" + str(m2_score) + " pts\n\nLoading Mission 3 — Fake Websites..."
		$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))
		$VBoxContainer/ProceedBtn.visible  = false
		$VBoxContainer/PwInput.editable    = false
		await get_tree().create_timer(3.5).timeout
		get_tree().change_scene_to_file("res://scenes/mission_website.tscn")
	else:
		_update_score_display()
		load_round()
