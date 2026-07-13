extends Control

var scenarios = [
	{
		"url": "http://natwest-verify.com/login",
		"https": false,
		"title": "NatWest Online Banking — Verify Your Account",
		"body": "Your account has been SUSPENDED due to suspicious activity.\n\nEnter your full name, date of birth, card number, and sort code immediately to restore access.\n\n⚠ You have 2 hours before your account is permanently closed.",
		"question": "What are the BIGGEST red flags on this website?",
		"options": [
			"The font looks slightly different from real NatWest",
			"No https, fake domain (natwest-verify.com not natwest.com), and asks for card/sort code",
			"The page has too much text for a real bank",
			"The bank logo colours are slightly wrong"
		],
		"correct": 1,
		"explanation": "🚩 THREE red flags: (1) No 'https' — no secure connection. (2) natwest-verify.com ≠ natwest.com — scammers add words to fake real domains. (3) Banks NEVER ask for card numbers or sort codes via a webpage link."
	},
	{
		"url": "https://www.paypa1-secure.co.uk/verify",
		"https": true,
		"title": "PayPal Security Centre — Account Limited",
		"body": "Your PayPal account has been LIMITED due to unusual activity.\n\nVerify your identity immediately to restore full access. You will need your email, password, and linked debit card details.\n\nThis process takes under 2 minutes.",
		"question": "Spot the fake — what is wrong with this PayPal website?",
		"options": [
			"PayPal does not have a Security Centre",
			"The page background is the wrong shade of blue",
			"'paypa1' uses the number 1 instead of the letter l in the URL",
			"The site uses https so it must be safe and genuine"
		],
		"correct": 2,
		"explanation": "🚩 TYPOSQUATTING: 'paypa1-secure.co.uk' swaps the letter 'l' for the number '1' — easy to miss at a glance! Real PayPal is always paypal.com. IMPORTANT: https only means the connection is encrypted, NOT that the site is legitimate. Scammers use https too!"
	},
	{
		"url": "https://www.amazon.co.uk/orders/track",
		"https": true,
		"title": "Amazon — Track Your Order",
		"body": "Hi Alex,\n\nYour order is on its way!\nOrder #205-7184920-3847162\nEstimated delivery: Tomorrow by 9pm\n\nClick 'Track Package' to see live delivery updates.\n\nThank you for shopping with Amazon.",
		"question": "Is this Amazon website real or fake?",
		"options": [
			"Fake — Amazon never sends order tracking pages",
			"Fake — the URL structure looks suspicious",
			"Real — amazon.co.uk is the correct UK domain with https, no red flags",
			"Real — but you should still avoid clicking Track Package"
		],
		"correct": 2,
		"explanation": "✅ SAFE: amazon.co.uk is the correct Amazon UK domain with https. The page requests nothing personal, creates no urgency, and has a legitimate order number. NOT every website is fake — recognising genuine sites is a key cyber skill!"
	},
	{
		"url": "http://www.hsbc-account-secure-verify.com",
		"https": false,
		"title": "HSBC Bank — URGENT Security Alert",
		"body": "⚠ CRITICAL SECURITY ALERT ⚠\n\nYour HSBC account has been SUSPENDED.\n\nTo avoid permanent closure you MUST verify within 1 HOUR:\n• Full name and date of birth\n• Card number and 3-digit CVV\n• Online banking PIN\n• Mother's maiden name\n\nFailure to act will result in legal proceedings.",
		"question": "How many serious red flags can you count on this HSBC site?",
		"options": [
			"1 — just the scary language is a bit over the top",
			"2 — fake domain and no https",
			"3 — fake domain, no https, and asks for PIN",
			"5 or more — domain, no https, PIN demand, CVV demand, 1-hour threat and legal threat"
		],
		"correct": 3,
		"explanation": "🚩 AT LEAST 5 RED FLAGS: (1) hsbc-account-secure-verify.com ≠ hsbc.co.uk. (2) No https. (3) Banks NEVER ask for your PIN — ever. (4) Asking for CVV online is illegal under PCI rules. (5) '1-hour' and 'legal proceedings' are fake pressure. Any ONE of these is enough to walk away!"
	}
]

var current_index = 0
var can_answer = true

func _ready():
	StyleManager.style_scene(self, "#0F6E56")
	StyleManager.add_back_button(self)
	StyleManager.make_alex(self, 820, 140, "neutral")
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
	$VBoxContainer/HintLabel.custom_minimum_size = Vector2(0, 44)

	# Browser panel — looks like a browser window
	var browser_style = StyleBoxFlat.new()
	browser_style.bg_color = Color("#0D1520")
	browser_style.border_color = Color("#1E3A5F")
	browser_style.set_border_width_all(2)
	browser_style.set_corner_radius_all(8)
	browser_style.content_margin_left   = 14
	browser_style.content_margin_right  = 14
	browser_style.content_margin_top    = 10
	browser_style.content_margin_bottom = 10
	browser_style.shadow_color  = Color(0, 0, 0, 0.5)
	browser_style.shadow_size   = 6
	browser_style.shadow_offset = Vector2(3, 4)
	$VBoxContainer/BrowserPanel.add_theme_stylebox_override("panel", browser_style)
	$VBoxContainer/BrowserPanel.custom_minimum_size = Vector2(640, 120)
	$VBoxContainer/BrowserPanel/BrowserVBox.add_theme_constant_override("separation", 6)

	$VBoxContainer/BrowserPanel/BrowserVBox/UrlLabel.add_theme_font_size_override("font_size", 14)
	$VBoxContainer/BrowserPanel/BrowserVBox/UrlLabel.add_theme_color_override("font_color", Color("#E24B4A"))

	$VBoxContainer/BrowserPanel/BrowserVBox/SiteTitle.add_theme_font_size_override("font_size", 18)
	$VBoxContainer/BrowserPanel/BrowserVBox/SiteTitle.add_theme_color_override("font_color", Color("#FFFFFF"))

	$VBoxContainer/BrowserPanel/BrowserVBox/SiteBody.add_theme_font_size_override("font_size", 13)
	$VBoxContainer/BrowserPanel/BrowserVBox/SiteBody.add_theme_color_override("font_color", Color("#85B7EB"))
	$VBoxContainer/BrowserPanel/BrowserVBox/SiteBody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
		StyleManager.style_button(btn, "#0A2218", "#FFFFFF")
		btn.custom_minimum_size = Vector2(620, 50)

func load_scenario():
	if current_index >= scenarios.size():
		finish_mission()
		return
	can_answer = true
	var s = scenarios[current_index]
	$VBoxContainer/Label.text = "Mission 3 — Scenario " + str(current_index + 1) + " of 4"
	$VBoxContainer/Label2.text = "Inspect the URL, padlock, content, and any urgent language"
	$VBoxContainer/HintLabel.text = "🔍 Scenario " + str(current_index + 1) + " of 4 — check EVERY detail of the browser bar"
	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + "   ❤ " + str(GameManager.lives)

	var url_node = $VBoxContainer/BrowserPanel/BrowserVBox/UrlLabel
	if s["https"] and "paypa1" not in s["url"] and "verify.com" not in s["url"]:
		url_node.text = "🔒 " + s["url"]
		url_node.add_theme_color_override("font_color", Color("#1D9E75"))
	else:
		url_node.text = "⚠ NOT SECURE  |  " + s["url"]
		url_node.add_theme_color_override("font_color", Color("#E24B4A"))

	$VBoxContainer/BrowserPanel/BrowserVBox/SiteTitle.text = s["title"]
	$VBoxContainer/BrowserPanel/BrowserVBox/SiteBody.text = s["body"]
	$VBoxContainer/QuestionLabel.text = s["question"]
	$VBoxContainer/FeedbackLabel.text = ""

	var opts = [$VBoxContainer/OptionsBox/Opt1, $VBoxContainer/OptionsBox/Opt2,
				$VBoxContainer/OptionsBox/Opt3, $VBoxContainer/OptionsBox/Opt4]
	var letters = ["A", "B", "C", "D"]
	for i in range(4):
		opts[i].text = letters[i] + ")  " + s["options"][i]
		opts[i].disabled = false
		opts[i].add_theme_color_override("font_color", Color("#FFFFFF"))

	# Animate browser panel
	$VBoxContainer/BrowserPanel.modulate.a = 0.0
	var tw = create_tween(); tw.set_trans(Tween.TRANS_QUAD); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property($VBoxContainer/BrowserPanel, "modulate:a", 1.0, 0.4)

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
		$VBoxContainer/FeedbackLabel.text = "✅  CORRECT! +" + str(pts) + " pts\n\n" + s["explanation"]
		$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#1D9E75"))
		StyleManager.screen_flash(self, Color("#1D9E75"))
		StyleManager.spawn_correct_particles(self, Vector2(580, 350))
		if GameManager.combo_streak >= 3:
			StyleManager.spawn_combo_banner(self, GameManager.combo_streak, GameManager.combo_mult)
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("correct")
	else:
		GameManager.lose_life()
		opts[index].add_theme_color_override("font_color", Color("#FF4444"))
		opts[s["correct"]].add_theme_color_override("font_color", Color("#1DFF88"))
		$VBoxContainer/FeedbackLabel.text = "❌  WRONG! -1 life\n\n" + s["explanation"]
		$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#E24B4A"))
		StyleManager.screen_flash(self, Color("#FF0000"))
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("wrong")

	$VBoxContainer/ScoreLabel.text = "Score: " + str(GameManager.score) + "   ❤ " + str(GameManager.lives)
	await get_tree().create_timer(3.8).timeout
	current_index += 1
	load_scenario()

func finish_mission():
	GameManager.complete_mission(3)
	var m3_score = GameManager.mission_scores.get(3, 0)
	$VBoxContainer/FeedbackLabel.text = "🎉 MISSION 3 COMPLETE!\nMission Score: +" + str(m3_score) + " pts\n\nLoading Mission 4 — Urgent Text..."
	$VBoxContainer/FeedbackLabel.add_theme_color_override("font_color", Color("#EF9F27"))
	StyleManager.screen_flash(self, Color("#00FFFF"))
	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://scenes/mission_sms.tscn")
