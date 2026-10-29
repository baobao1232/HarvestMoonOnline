extends NPCData
# Karen.gd - script riêng của Karen.
# Dữ liệu (lịch, thoại, quà...) do NpcManager tải từ server: .../hvm/npc-data/karen.json
# rồi đưa vào qua load_dict(). Bản Karen.json cạnh file này chỉ là dự phòng khi mất mạng.
#
# Cần logic riêng cho NPC này thì override hàm của NPCData ở đây, ví dụ:
#   func pick_dialog(ctx, entry):
#       if get_hearts() >= 10: return _lines("marry")
#       return super(ctx, entry)
