extends Node
## Steins;Gate-like phone/mail trigger state. UI can be swapped independently.

signal mail_received(mail_id: String, sender: String, subject: String)
signal mail_read(mail_id: String)
signal mail_replied(mail_id: String, keyword: String)
signal phone_opened(screen: String)
signal phone_closed()

var inbox: Array[Dictionary] = []
var replies: Dictionary = {}
var opened := false
var current_screen := "inbox"

func reset() -> void:
	inbox.clear()
	replies.clear()
	opened = false
	current_screen = "inbox"

func receive_mail(mail_id: String, sender: String, subject: String, body: String) -> void:
	var existing: Variant = _find_mail(mail_id)
	if existing != null:
		existing["sender"] = sender
		existing["subject"] = subject
		existing["body"] = body
	else:
		inbox.append({"id": mail_id, "sender": sender, "subject": subject, "body": body, "read": false})
	VNState.set_flag("mail_received_%s" % mail_id, true)
	mail_received.emit(mail_id, sender, subject)

func mark_read(mail_id: String) -> void:
	var mail: Variant = _find_mail(mail_id)
	if mail == null:
		push_warning("PhoneSystem: cannot read missing mail %s" % mail_id)
		return
	mail["read"] = true
	VNState.set_flag("mail_read_%s" % mail_id, true)
	mail_read.emit(mail_id)

func reply_mail(mail_id: String, keyword: String) -> void:
	if _find_mail(mail_id) == null:
		push_warning("PhoneSystem: cannot reply to missing mail %s" % mail_id)
		return
	replies[mail_id] = keyword
	VNState.set_flag("mail_reply_%s" % mail_id, true)
	VNState.set_var("mail_reply_keyword_%s" % mail_id, keyword)
	mail_replied.emit(mail_id, keyword)

func open(screen: String = "inbox") -> void:
	opened = true
	current_screen = screen
	phone_opened.emit(screen)

func close() -> void:
	opened = false
	phone_closed.emit()

func snapshot() -> Dictionary:
	return {
		"inbox": inbox.duplicate(true),
		"replies": replies.duplicate(true),
		"opened": opened,
		"current_screen": current_screen,
	}

func restore(data: Dictionary) -> void:
	reset()
	for item in data.get("inbox", []):
		if typeof(item) == TYPE_DICTIONARY:
			inbox.append(item.duplicate(true))
	replies = data.get("replies", {}).duplicate(true)
	opened = bool(data.get("opened", false))
	current_screen = str(data.get("current_screen", "inbox"))

func _find_mail(mail_id: String) -> Variant:
	for mail in inbox:
		if str(mail.get("id", "")) == mail_id:
			return mail
	return null
