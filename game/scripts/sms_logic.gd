extends Control

var scenarios = [
	{
		"sender": "Royal Mail  |  +44 7700 900341",
		"time": "Today 11:23",
		"message": "Your parcel could not be delivered. A fee of £1.99 is required to rebook delivery. Pay within 12 hours:\nroyalmai1-fees.co.uk/rebook?ref=RM00419\n\nIgnoring this will result in return to sender.",
		"question": "What should Alex do with this Royal Mail text?",
		"options": [
			"Click the link and pay £1.99 quickly",
			"Reply to the number asking if it is genuine",
			"Ignore it completely",
			"Forward to 7726 (free spam report) then delete it"
		],
		"correct": 3,
		"explanation": "SMISHING: Royal Mail NEVER texts asking for payment via a link. 'royalmai1' uses number 1 not letter l. Always forward suspicious texts to 7726 (the UK spam-reporting shortcode) then delete. Never click unknown links!"
	},
	{
		"sender": "HMRC-UK  |  Shortcode: 60886",
		"time": "Today 09:05",
		"message": "URGENT: A tax refund of £342.50 is owed to you. Claim your refund within 48 hours or it will be forfeited:\nhmrc-refund-claim.net/apply?code=TXR8821\n\nHM Revenue & Customs",
		"question": "What is the biggest red flag in this HMRC text?",
		"options": [
			"HMRC never gives tax refunds",
			"The link uses hmrc-refund-claim.net instead of hmrc.gov.uk",
			"The refund amount is too large",
			"HMRC only contacts by letter"
		],
		"correct": 1,
		"explanation": "PHISHING: Real HMRC only uses hmrc.gov.uk — never a third-party domain. HMRC will NEVER text you a link to claim a refund. Tax refunds are processed automatically. If in doubt, go directly to gov.uk, never via a link."
	},
	{
		"sender": "NatWest  |  +44 800 141 4422",
		"time": "Today 14:47",
		"message": "ALERT: Your NatWest debit card has been blocked due to suspicious activity.\n\nCall 0800 123 456 IMMEDIATELY to restore your account and prevent permanent closure.",
		"question": "How should Alex respond to this urgent NatWest text?",
		"options": [
			"Call 0800 123 456 right away — it sounds urgent",
			"Reply with your account number to verify",
			"Call the number printed on the BACK of your bank card instead",
			"Ignore it — banks never text customers"
		],
		"correct": 2,
		"explanation": "VISHING RISK: Never call numbers given in suspicious texts — scammers use fake numbers. The REAL NatWest number is on the back of your card and at natwest.com. Banks do genuinely text alerts, but always verify by calling the official number only."
	},
	{
		"sender": "Amazon  |  Shortcode: 86644",
		"time": "Yesterday 18:12",
		"message": "Your Amazon order #205-7184920 has shipped!\nEstimated delivery: Tomorrow by 9pm\n\nTrack your parcel: amazon.co.uk/orders\n\nNo action needed.",
		"question": "Is this Amazon text message a scam?",
		"options": [
			"Yes — Amazon never sends text messages",
			"Yes — it contains a suspicious link",
			"No — amazon.co.uk is real and no personal info is requested",
			"Unsure — delete it just in case"
		],
		"correct": 2,
		"explanation": "SAFE: This is a legitimate Amazon notification. amazon.co.uk is the correct UK domain. It requests nothing personal, creates no urgency, and is tracking-only. NOT every text is a scam — recognising safe messages is just as important as spotting fake ones!"
	}
]

var current_index = 0
var can_answer = true

func _ready():
	StyleManager.style_scene(self, "#534AB7")
	StyleManager.add_back_button(self)
	StyleManager.make_alex(self, 820, 140, "worried")
	_style_ui()
	load_scenario()
	$VBoxContainer/OptionsBox/Opt1.pressed.connect(func(): check_answer(0))
	$VBoxContainer/OptionsBox/Opt2.pressed.connect(func(): check_answer(1))
	$VBoxContainer/OptionsBox/Opt3.pressed.connect(func(): check_answer(2))
	$VBoxContainer/OptionsBox/Opt4.pressed.connect(func(): check_answer(3))

func _style_ui():
	$ColorRect.color = Color("#0D1B2A")
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$VBoxContainer/Label.add_theme_font_size_override("font_size", 28)
	$VBoxContainer/Label.add_theme_color_override("font_color", Color("#FFFFFF"))

	$VBoxContainer/Label2.add_theme_font_size_override("font_size", 16)
	$VBoxContainer/Label2.add_theme_color_override("font_color", Color("#85B7EB"))

	$VBoxContainer/ScoreLabel.add_theme_font_size_override("font_size", 17)
	$VBoxContainer/ScoreLabel.add_theme_color_override("font_color", Color("#85B7EB"))

	$VBoxContainer/HintLabel.add_theme_font_size_override("font_size", 15)
	$VBoxContainer/HintLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	$VBoxContainer/HintLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/HintLabel.custom_minimum_size = Vector2(0, 54)

	# Phone panel style — looks like a dark phone screen
	var phone_style = StyleBoxFlat.new()
	phone_style.bg_color = Color("#0A0F1A")
	phone_style.border_color = Color("#534AB7")
	phone_style.set_border_width_all(2)
	phone_style.set_corner_radius_all(14)
	phone_style.content_margin_left   = 18
	phone_style.content_margin_right  = 18
	phone_style.content_margin_top    = 14
	phone_style.content_margin_bottom = 14
	phone_style.shadow_color  = Color(0, 0, 0, 0.6)
	phone_style.shadow_size   = 8
	phone_style.shadow_offset = Vector2(3, 5)
	$VBoxContainer/PhonePanel.add_theme_stylebox_override("panel", phone_style)
	$VBoxContainer/PhonePanel.custom_minimum_size = Vector2(560, 110)

	$VBoxContainer/PhonePanel/PhoneVBox.add_theme_constant_override("separation", 8)

	$VBoxContainer/PhonePanel/PhoneVBox/SenderLabel.add_theme_font_size_override("font_size", 14)
	$VBoxContainer/PhonePanel/PhoneVBox/SenderLabel.add_theme_color_override("font_color", Color("#6B60C7"))

	$VBoxContainer/PhonePanel/PhoneVBox/MessageLabel.add_theme_font_size_override("font_size", 15)
	$VBoxContainer/PhonePanel/PhoneVBox/MessageLabel.add_theme_color_override("font_color", Color("#D0D8F0"))
	$VBoxContainer/PhonePanel/PhoneVBox/MessageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	$VBoxContainer/QuestionLabel.add_theme_font_size_override("font_size", 18)
	$VBoxContainer/QuestionLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	$VBoxContainer/QuestionLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/QuestionLabel.custom_minimum_size = Vector2(0, 50)

	$VBoxContainer/FeedbackLabel.add_theme_font_size_override("font_size", 15)
	$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#1D9E75"))
	$VBoxContainer/FeedbackLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/FeedbackLabel.custom_minimum_size = Vector2(0, 70)

	for btn in [$VBoxContainer/OptionsBox/Opt1, $VBoxContainer/OptionsBox/Opt2,
				$VBoxContainer/OptionsBox/Opt3, $VBoxContainer/OptionsBox/Opt4]:
		StyleManager.style_button(btn, "#2D2480", "#FFFFFF")
		btn.custom_minimum_size = Vector2(600, 50)

func load_scenario():
	if current_index >= scenarios.size():
		finish_mission()
		return
	can_answer = true
	var s = scenarios[current_index]
	$VBoxContainer/Label.text = "Mission 4 — Message " + str(current_index + 1) + " of 4"
	$VBoxContainer/Label2.text = "Alex received this text — read carefully and decide what to do!"
	$VBoxContainer/HintLabel.text = "📱 Message " + str(current_index + 1) + " of 4 — look at the sender, the link, and the urgency"
	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + "   ❤ " + str(GameManager.lives)
	$VBoxContainer/PhonePanel/PhoneVBox/SenderLabel.text = "📱 " + s["sender"] + "  •  " + s["time"]
	$VBoxContainer/PhonePanel/PhoneVBox/MessageLabel.text = s["message"]
	$VBoxContainer/QuestionLabel.text = s["question"]
	$VBoxContainer/FeedbackLabel.text = ""
	var opts = [$VBoxContainer/OptionsBox/Opt1, $VBoxContainer/OptionsBox/Opt2,
				$VBoxContainer/OptionsBox/Opt3, $VBoxContainer/OptionsBox/Opt4]
	var letters = ["A", "B", "C", "D"]
	for i in range(4):
		opts[i].text = letters[i] + ")  " + s["options"][i]
		opts[i].disabled = false
		opts[i].add_theme_color_override("font_color", Color("#FFFFFF"))

	# Slide phone panel in
	$VBoxContainer/PhonePanel.modulate.a = 0.0
	$VBoxContainer/PhonePanel.position.x = -200
	var tw = create_tween(); tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property($VBoxContainer/PhonePanel, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property($VBoxContainer/PhonePanel, "position:x", 0.0, 0.35)

func check_answer(index):
	if not can_answer: return
	can_answer = false
	var s = scenarios[current_index]
	var opts = [$VBoxContainer/OptionsBox/Opt1, $VBoxContainer/OptionsBox/Opt2,
				$VBoxContainer/OptionsBox/Opt3, $VBoxContainer/OptionsBox/Opt4]
	for btn in opts: btn.disabled = true

	if index == s["correct"]:
		var pts = GameManager.add_score(15)
		opts[index].add_theme_color_override("font_color", Color("#1DFF88"))
		$VBoxContainer/FeedbackLabel.text = "✅  CORRECT! +" + str(pts) + " pts\n" + s["explanation"]
		$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#1D9E75"))
		StyleManager.screen_flash(self, Color("#1D9E75"))
		if GameManager.combo_streak >= 3:
			StyleManager.spawn_combo_banner(self, GameManager.combo_streak, GameManager.combo_mult)
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("correct")
	else:
		GameManager.lose_life()
		opts[index].add_theme_color_override("font_color", Color("#FF4444"))
		opts[s["correct"]].add_theme_color_override("font_color", Color("#1DFF88"))
		$VBoxContainer/FeedbackLabel.text = "❌  WRONG! -1 life\nCorrect answer: " + s["options"][s["correct"]] + "\n\n" + s["explanation"]
		$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#E24B4A"))
		StyleManager.screen_flash(self, Color("#FF0000"))
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("wrong")

	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + "   ❤ " + str(GameManager.lives)
	await get_tree().create_timer(3.5).timeout
	current_index += 1
	load_scenario()

func finish_mission():
	GameManager.complete_mission(4)
	var m4_score = GameManager.mission_scores.get(4, 0)
	$VBoxContainer/FeedbackLabel.text = "🎉 MISSION 4 COMPLETE!\nMission Score: +" + str(m4_score) + " pts\n\nLoading the FINAL BOSS — Mission 5..."
	$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	StyleManager.screen_flash(self, Color("#00FFFF"))
	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://scenes/mission_boss.tscn")
