extends Node
## Route and ending arbitration. Keep route locks here instead of scattering them in UI.

func decide_white_album_style_route() -> String:
	var setsuna := VNState.get_affection("setsuna")
	var kazusa := VNState.get_affection("kazusa")
	if VNState.get_flag("route_locked_setsuna"):
		return "setsuna"
	if VNState.get_flag("route_locked_kazusa"):
		return "kazusa"
	if kazusa > setsuna + 2:
		return "kazusa"
	if setsuna > kazusa + 2:
		return "setsuna"
	return "common"

func decide_steins_gate_style_ending() -> String:
	if VNState.get_flag("true_end_unlocked") and VNState.get_flag("sent_final_dmail"):
		return "true_end"
	if VNState.get_flag("ignored_critical_phone_trigger"):
		return "bad_end"
	if VNState.get_flag("kurisu_mail_chain_complete"):
		return "kurisu_end"
	return "common_end"

func lock_route(route_id: String) -> void:
	VNState.set_route(route_id)
	VNState.set_flag("route_locked_%s" % route_id, true)
