extends Control

func _ready():
	StyleManager.style_scene(self, "#7A5900")
	StyleManager.add_back_button(self, "res://scenes/main_menu.tscn")
	StyleManager.make_alex(self, 820, 150, "happy")
	$ColorRect.color = Color("#0D1B2A")
	style_ui()
	show_results()
	$VBoxContainer/ReplayBtn.pressed.connect(_on_replay)
	$VBoxContainer/QuitBtn.pressed.connect(_on_quit)

func style_ui():
	$VBoxContainer/Label.add_theme_font_size_override("font_size", 32)
	$VBoxContainer/Label.add_theme_color_override("font_color", Color("#EF9F27"))
	$VBoxContainer/RankLabel.add_theme_font_size_override("font_size", 40)
	$VBoxContainer/RankLabel.add_theme_color_override("font_color", Color("#FFFFFF"))
	$VBoxContainer/ScoreLabel.add_theme_font_size_override("font_size", 22)
	$VBoxContainer/ScoreLabel.add_theme_color_override("font_color", Color("#85B7EB"))
	$VBoxContainer/LivesLabel.add_theme_font_size_override("font_size", 20)
	$VBoxContainer/LivesLabel.add_theme_color_override("font_color", Color("#85B7EB"))
	$VBoxContainer/GradeLabel.add_theme_font_size_override("font_size", 24)
	$VBoxContainer/GradeLabel.add_theme_color_override("font_color", Color("#1D9E75"))
	$VBoxContainer/MessageLabel.add_theme_font_size_override("font_size", 16)
	$VBoxContainer/MessageLabel.add_theme_color_override("font_color", Color("#4A6B8A"))
	$VBoxContainer/MessageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer/MessageLabel.custom_minimum_size = Vector2(0, 80)
	StyleManager.style_button($VBoxContainer/ReplayBtn, "#1D9E75", "#FFFFFF")
	StyleManager.style_button($VBoxContainer/QuitBtn, "#185FA5", "#FFFFFF")
	$VBoxContainer/ReplayBtn.custom_minimum_size = Vector2(300, 56)
	$VBoxContainer/QuitBtn.custom_minimum_size = Vector2(300, 56)

func show_results():
	var score = GameManager.score
	var lives = GameManager.lives
	var max_score = 350
	var pct = min(100, int((float(score) / float(max_score)) * 100))
	var rank = ""
	var grade = ""
	var message = ""
	var rank_color = Color("#FFFFFF")
	if pct >= 90:
		rank = "ELITE GUARDIAN"
		grade = "Outstanding! Perfect score!"
		message = "You are a true cyber security expert. You identified every threat, spotted every scam, and protected Alex completely!"
		rank_color = Color("#EF9F27")
	elif pct >= 75:
		rank = "SENIOR AGENT"
		grade = "Excellent work!"
		message = "You have strong cyber security skills. Review any mistakes and you will be Elite level next time!"
		rank_color = Color("#1D9E75")
	elif pct >= 50:
		rank = "AGENT"
		grade = "Good effort!"
		message = "You have a solid foundation. Keep practising and pay special attention to fake domains and password strength!"
		rank_color = Color("#85B7EB")
	else:
		rank = "ROOKIE"
		grade = "Keep learning!"
		message = "Cyber security takes practice. Always check URLs carefully, use strong unique passwords, and never click suspicious links!"
		rank_color = Color("#E24B4A")
	$VBoxContainer/Label.text = "GAME COMPLETE!"
	$VBoxContainer/RankLabel.text = rank
	$VBoxContainer/RankLabel.add_theme_color_override("font_color", rank_color)
	var bonus_note = " + combo bonuses!" if score > max_score else ""
	$VBoxContainer/ScoreLabel.text = "Final Score: " + str(score) + " pts  (" + str(pct) + "%" + bonus_note + ")"
	var max_lives = SettingsManager.get_lives() if SettingsManager else 3
	$VBoxContainer/LivesLabel.text = "Lives remaining: " + str(lives) + " / " + str(max_lives)
	$VBoxContainer/GradeLabel.text = grade
	$VBoxContainer/GradeLabel.add_theme_color_override("font_color", rank_color)
	$VBoxContainer/MessageLabel.text = message

func _on_replay():
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_quit():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
