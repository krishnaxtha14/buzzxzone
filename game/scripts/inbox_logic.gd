extends Control

var emails = [
	{
		"from": "noreply@paypa1-secure.net",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Today, 09:14 AM",
		"subj": "URGENT: Your PayPal account has been SUSPENDED",
		"preview": "Dear Customer,\n\nWe detected unusual activity on your PayPal account. Your account has been LIMITED.\n\nClick here immediately to verify your identity:\nhttp://paypa1-secure.net/verify?id=38291\n\nFailure to verify within 24 hours will result in permanent suspension.\n\nPayPal Security Team",
		"scam": true,
		"hint": "RED FLAGS: 'paypa1' uses number 1 not letter l. Real PayPal domain is paypal.com. Urgent 24-hour threats are pressure tactics. Real PayPal never links to paypa1-secure.net."
	},
	{
		"from": "timetables@coventry.ac.uk",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Today, 08:47 AM",
		"subj": "Your updated timetable for next semester",
		"preview": "Hi Alex,\n\nPlease find your updated lecture timetable for next semester attached below. Room changes have been highlighted in yellow.\n\nIf you have any queries, contact your personal tutor.\n\nBest regards,\nCoventry University Registry",
		"scam": false,
		"hint": "SAFE: coventry.ac.uk is the official university domain. No suspicious links, no urgent demands, no requests for personal information. Normal administrative email."
	},
	{
		"from": "prize@win-now99.net",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Today, 07:02 AM",
		"subj": "Congratulations! You WON £500 — Claim in 24 HRS!",
		"preview": "CONGRATULATIONS WINNER!\n\nYou have been RANDOMLY SELECTED to receive £500.00!\n\nTo claim your prize, click below and enter your bank details:\nhttp://win-now99.net/claim?ref=ALEX500\n\nOffer expires in 24 hours. Act NOW!\n\n— Prize Team",
		"scam": true,
		"hint": "RED FLAGS: You never entered this competition. win-now99.net is not a real organisation. Asking for bank details = immediate scam. '24 hours' creates false urgency. Legitimate prizes do not ask for bank details upfront."
	},
	{
		"from": "shipment-update@amazon.co.uk",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Yesterday, 3:22 PM",
		"subj": "Your Amazon order has shipped — Track your parcel",
		"preview": "Hi Alex,\n\nGood news! Your order has been dispatched.\nOrder #205-7184920-3847162\nEstimated delivery: Tomorrow by 9pm\n\nTrack your parcel at:\namazon.co.uk/your-orders\n\nThank you for shopping with Amazon.",
		"scam": false,
		"hint": "SAFE: amazon.co.uk is the legitimate UK Amazon domain. The order number looks real. No personal information requested. Link goes to the official domain, not a redirect. Normal shipping notification."
	},
	{
		"from": "alert@natwest-verify.com",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Today, 11:58 AM",
		"subj": "IMPORTANT: Unusual login detected on your account",
		"preview": "Dear NatWest Customer,\n\nWe detected a login attempt from an unrecognised device (Windows, London).\n\nIf this was NOT you, verify your account immediately:\nhttp://natwest-verify.com/secure-login\n\nYour account will be frozen in 2 hours if unverified.\n\nNatWest Security",
		"scam": true,
		"hint": "RED FLAGS: natwest-verify.com is NOT natwest.com — scammers add words to fake bank domains. Real NatWest uses natwest.com only. Never click links in bank security emails — call the number on the back of your card instead."
	},
	{
		"from": "library@coventry.ac.uk",
		"to": "alex.johnson@student.coventry.ac.uk",
		"time": "Yesterday, 10:00 AM",
		"subj": "Library reminder: Books due back this Friday",
		"preview": "Hi Alex,\n\nThis is a reminder that the following items are due for return this Friday 14th:\n\n• Introduction to Cybersecurity (Stallings)\n• Network Security Essentials\n\nRenew online at: library.coventry.ac.uk\n\nCoventry University Library Services",
		"scam": false,
		"hint": "SAFE: coventry.ac.uk is the real university domain. Simple reminder with no financial requests, no urgency pressure, no suspicious links. Renew link goes to the official library subdomain."
	}
]

var current_index = 0
var can_sort = true
var card_panel
var from_label
var to_label
var time_label
var subj_label
var preview_label
var progress_label
var alex_node

func _ready():
	StyleManager.style_scene(self, "#185FA5")
	StyleManager.add_back_button(self)
	alex_node = StyleManager.make_alex(self, 820, 150, "happy")
	build_ui()
	show_email()
	$VBoxContainer/HBoxContainer/SafeBtn.pressed.connect(func(): sort_email("safe"))
	$VBoxContainer/HBoxContainer/BinBtn.pressed.connect(func(): sort_email("bin"))

func build_ui():
	$ColorRect.color = Color("#0D1B2A")
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBoxContainer/Label.add_theme_font_size_override("font_size", 28)
	$VBoxContainer/Label.add_theme_color_override("font_color", Color("#FFFFFF"))
	$VBoxContainer/Label.text = "Mission 1 — The Suspicious Inbox"
	$VBoxContainer/Label2.add_theme_font_size_override("font_size", 16)
	$VBoxContainer/Label2.add_theme_color_override("font_color", Color("#85B7EB"))
	$VBoxContainer/Label2.text = "Read each email carefully — spot the red flags before sorting!"
	$VBoxContainer/HintLabel.add_theme_font_size_override("font_size", 15)
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	$VBoxContainer/HintLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/HintLabel.custom_minimum_size = Vector2(0, 72)
	$VBoxContainer/ScoreLabel.add_theme_font_size_override("font_size", 17)
	$VBoxContainer/ScoreLabel.add_theme_color_override("font_color", Color("#85B7EB"))
	StyleManager.style_button($VBoxContainer/HBoxContainer/SafeBtn, "#1D9E75", "#FFFFFF")
	StyleManager.style_button($VBoxContainer/HBoxContainer/BinBtn, "#E24B4A", "#FFFFFF")
	$VBoxContainer/HBoxContainer/SafeBtn.text = "✅  SAFE INBOX"
	$VBoxContainer/HBoxContainer/BinBtn.text  = "🗑  SCAM BIN"
	$VBoxContainer/HBoxContainer/SafeBtn.custom_minimum_size = Vector2(260, 58)
	$VBoxContainer/HBoxContainer/BinBtn.custom_minimum_size  = Vector2(260, 58)

	var stack = $VBoxContainer/EmailStack
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 15)
	progress_label.add_theme_color_override("font_color", Color("#4A6B8A"))
	stack.add_child(progress_label)

	# Email card
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(640, 155)
	stack.add_child(card_panel)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#0A1828")
	card_style.border_color = Color("#1E3A5F")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left   = 16
	card_style.content_margin_right  = 16
	card_style.content_margin_top    = 12
	card_style.content_margin_bottom = 12
	card_style.shadow_color  = Color(0, 0, 0, 0.5)
	card_style.shadow_size   = 6
	card_style.shadow_offset = Vector2(3, 4)
	card_panel.add_theme_stylebox_override("panel", card_style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	card_panel.add_child(card_vbox)

	# Header rows
	var _add_row = func(icon_text: String, color_hex: String) -> Label:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card_vbox.add_child(row)
		var icon = Label.new()
		icon.text = icon_text
		icon.add_theme_font_size_override("font_size", 13)
		icon.add_theme_color_override("font_color", Color("#4A6B8A"))
		icon.custom_minimum_size = Vector2(48, 0)
		row.add_child(icon)
		var val = Label.new()
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", Color(color_hex))
		row.add_child(val)
		return val

	from_label = _add_row.call("From:", "#85B7EB")
	to_label   = _add_row.call("To:",   "#4A6B8A")
	time_label = _add_row.call("Time:", "#4A6B8A")

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color("#1E3A5F"))
	card_vbox.add_child(sep)

	subj_label = Label.new()
	subj_label.add_theme_font_size_override("font_size", 17)
	subj_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	subj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(subj_label)

	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("color", Color("#0F2035"))
	card_vbox.add_child(sep2)

	preview_label = Label.new()
	preview_label.add_theme_font_size_override("font_size", 13)
	preview_label.add_theme_color_override("font_color", Color("#5A7A9A"))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.custom_minimum_size = Vector2(0, 60)
	card_vbox.add_child(preview_label)

func show_email():
	if current_index >= emails.size():
		finish_mission()
		return
	can_sort = true
	$VBoxContainer/HBoxContainer/SafeBtn.disabled = false
	$VBoxContainer/HBoxContainer/BinBtn.disabled  = false
	var email = emails[current_index]
	progress_label.text = "Email " + str(current_index + 1) + " of " + str(emails.size())

	card_panel.modulate = Color(1, 1, 1, 1)
	from_label.text    = email["from"]
	to_label.text      = email["to"]
	time_label.text    = email["time"]
	subj_label.text    = email["subj"]
	preview_label.text = email["preview"]

	# Highlight suspicious sender address in red
	if email["scam"]:
		from_label.add_theme_color_override("font_color", Color("#E24B4A"))
	else:
		from_label.add_theme_color_override("font_color", Color("#1D9E75"))

	$VBoxContainer/HintLabel.text = "Read every detail carefully — sender address, links, urgency, and tone."
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#4A6B8A"))
	update_score()

	# Slide card in from right
	card_panel.position.x = 420
	card_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(card_panel, "position:x", 0.0, 0.38)
	tw.parallel().tween_property(card_panel, "modulate:a", 1.0, 0.30)

func sort_email(zone):
	if not can_sort: return
	can_sort = false
	$VBoxContainer/HBoxContainer/SafeBtn.disabled = true
	$VBoxContainer/HBoxContainer/BinBtn.disabled  = true
	var email   = emails[current_index]
	var correct = (zone == "safe" and not email["scam"]) or (zone == "bin" and email["scam"])
	if correct:
		var pts = GameManager.add_score(10)
		$VBoxContainer/HintLabel.text = "✅  CORRECT! +" + str(pts) + " pts\n" + email["hint"]
		$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#1D9E75"))
		card_panel.modulate = Color("#1DFF88")
		StyleManager.screen_flash(self, Color("#1D9E75"))
		StyleManager.alex_celebrate(alex_node)
		StyleManager.spawn_correct_particles(self, Vector2(760, 320))
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("correct")
	else:
		GameManager.lose_life()
		$VBoxContainer/HintLabel.text = "❌  WRONG! -1 life\n" + email["hint"]
		$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#E24B4A"))
		card_panel.modulate = Color("#FF4444")
		StyleManager.screen_flash(self, Color("#FF0000"))
		StyleManager.alex_sad(alex_node)
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("wrong")
	update_score()
	await get_tree().create_timer(2.2).timeout
	current_index += 1
	show_email()

func update_score():
	var combo_txt = ""
	if GameManager.combo_streak >= 3:
		combo_txt = "  🔥 Combo x" + str(snappedf(GameManager.combo_mult, 0.5)).trim_suffix(".0") + "!"
	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + "   ❤ " + str(GameManager.lives) + combo_txt

func finish_mission():
	GameManager.complete_mission(1)
	$VBoxContainer/HBoxContainer/SafeBtn.visible = false
	$VBoxContainer/HBoxContainer/BinBtn.visible  = false
	StyleManager.alex_celebrate(alex_node)
	StyleManager.spawn_correct_particles(self, Vector2(760, 300))
	StyleManager.spawn_correct_particles(self, Vector2(760, 400))
	var m1_score = GameManager.mission_scores.get(1, 0)
	var grade = ""
	if m1_score >= 80: grade = "🏆 Outstanding Guardian!"
	elif m1_score >= 60: grade = "⭐ Great work!"
	elif m1_score >= 40: grade = "👍 Good effort!"
	else: grade = "📚 Keep practising!"
	$VBoxContainer/HintLabel.text = "🎉 MISSION 1 COMPLETE!\nMission Score: +" + str(m1_score) + " pts   " + grade + "\n\nLoading Mission 2 — Password Security..."
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://scenes/mission_password.tscn")
