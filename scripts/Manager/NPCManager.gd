extends Node

var npc_scenes = {
	"Ann": preload("res://scn/NPC/Ann.tscn")
}


func spawn_npcs(current_map: String, parent: Node):

	print("=== NPC SPAWN START ===")
	print("Current map:", current_map)
	print("Current hour:", TimeManager.hour)

	for npc_id in npc_scenes.keys():

		print("Checking NPC:", npc_id)

		var path = "res://scripts/NPCS/%s/%s.gd" % [npc_id, npc_id]

		if not ResourceLoader.exists(path):
			print("NPC data not found:", path)
			continue

		var script = load(path)
		var data = script.new()

		if not data.has_method("_init") and not "schedule" in data:
			print("NPC schedule missing:", npc_id)
			continue

		var schedule = data.schedule
		var current_hour = TimeManager.hour
		var last_event = null


		for s in schedule:

			print("Schedule event:", s)

			if int(s.hour) <= current_hour:
				last_event = s


		if last_event == null:
			print("No valid schedule for:", npc_id)
			continue


		print("Last event map:", last_event.map)

		if last_event.map == current_map:

			var npc = npc_scenes[npc_id].instantiate()

			npc.global_position = last_event.pos

			parent.add_child(npc)

			print("SPAWN NPC:", npc_id, "POS:", last_event.pos)

		else:
			print("NPC not in this map")
