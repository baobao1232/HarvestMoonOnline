extends Resource

# ======================
# SCHEDULE
# ======================

var schedule = [
	{ "hour": 6, "map": "Forest", "pos": Vector2(318,123) }
]


# ======================
# PORTRAITS
# ======================

var portraits = {

"normal": preload("res://Assest/Npc/Ann/ann_normal.png"),
"happy": preload("res://Assest/Npc/Ann/ann_happy.png"),
"angry": preload("res://Assest/Npc/Ann/ann_angry.png"),
"shy": preload("res://Assest/Npc/Ann/ann_shy.png"),
"sad": preload("res://Assest/Npc/Ann/ann_sad.png"),
"thinking": preload("res://Assest/Npc/Ann/ann_thinking.png"),
"marry": preload("res://Assest/Npc/Ann/ann_marry.png")

}


# ======================
# DIALOG DATABASE
# ======================

var dialog = {

# ======================
# INTRO
# ======================

"intro":[

{ "text":"Xin lỗi… chúng ta đã gặp nhau chưa?", "face":"thinking" },
{ "text":"À! Bạn là nông dân mới chuyển đến phải không?", "face":"normal" },
{ "text":"Tôi là Ann.", "face":"happy" },
{ "text":"Rất vui được gặp bạn!", "face":"happy" },
{ "text":"Nếu bạn cần chỗ nghỉ ngơi, hãy ghé quán trọ của chúng tôi.", "face":"normal" }

],


# ======================
# NORMAL
# ======================

"normal":[

{ "text":"Chào bạn!", "face":"happy" },
{ "text":"Hôm nay bạn làm việc trên nông trại à?", "face":"normal" },
{ "text":"Nông dân chắc hẳn phải rất bận rộn.", "face":"thinking" },

{ "text":"Tôi giúp bố quản lý quán trọ.", "face":"normal" },
{ "text":"Nơi đó lúc nào cũng khá đông khách.", "face":"happy" },

{ "text":"Nếu bạn mệt, hãy ghé quán trọ nghỉ một chút nhé.", "face":"happy" },

{ "text":"Tôi thích nấu ăn.", "face":"happy" },
{ "text":"Tôi luôn muốn thử những công thức mới.", "face":"thinking" },

{ "text":"Bạn đã quen với thị trấn chưa?", "face":"normal" }

],


# ======================
# RAIN
# ======================

"rain":[

{ "text":"Tôi không thích trời mưa.", "face":"sad" },
{ "text":"Mọi thứ trở nên ẩm ướt.", "face":"thinking" },
{ "text":"Quán trọ thường vắng khách hơn khi trời mưa.", "face":"sad" },
{ "text":"Nhưng đôi khi trời mưa cũng khiến mọi thứ yên tĩnh hơn.", "face":"normal" }

],


# ======================
# EVENING
# ======================

"evening":[

{ "text":"Tối rồi nhỉ.", "face":"normal" },
{ "text":"Quán trọ thường rất đông khách vào buổi tối.", "face":"happy" },
{ "text":"Chúng tôi phải chuẩn bị rất nhiều thức ăn.", "face":"thinking" },
{ "text":"Nhưng tôi cũng thích không khí nhộn nhịp đó.", "face":"happy" }

],


# ======================
# SPRING
# ======================

"spring":[

{ "text":"Mùa xuân thật dễ chịu.", "face":"happy" },
{ "text":"Hoa nở khắp nơi.", "face":"happy" },
{ "text":"Tôi thích mùi hương của mùa xuân.", "face":"thinking" },

{ "text":"Nông trại của bạn chắc đang rất bận rộn.", "face":"normal" },
{ "text":"Đây là mùa tốt để bắt đầu mọi thứ.", "face":"happy" }

],


# ======================
# SUMMER
# ======================

"summer":[

{ "text":"Trời nóng thật đấy.", "face":"thinking" },
{ "text":"Làm việc trong bếp lúc này hơi mệt.", "face":"sad" },

{ "text":"Bạn nhớ uống đủ nước nhé.", "face":"normal" },

{ "text":"Mùa hè có rất nhiều nguyên liệu nấu ăn ngon.", "face":"happy" }

],


# ======================
# FALL
# ======================

"fall":[

{ "text":"Mùa thu có nhiều nguyên liệu nấu ăn.", "face":"happy" },
{ "text":"Tôi muốn thử nhiều món mới.", "face":"happy" },

{ "text":"Không khí mùa thu thật dễ chịu.", "face":"thinking" }

],


# ======================
# WINTER
# ======================

"winter":[

{ "text":"Trời lạnh quá.", "face":"sad" },
{ "text":"Tôi thích những món ăn nóng.", "face":"happy" },

{ "text":"Bạn nhớ mặc ấm nhé.", "face":"normal" }

],


# ======================
# FRIENDSHIP (HEART)
# ======================

"heart2":[

{ "text":"Tôi luôn thấy vui khi gặp bạn.", "face":"happy" },
{ "text":"Bạn là người rất chăm chỉ.", "face":"happy" }

],


"heart4":[

{ "text":"Bạn làm việc rất chăm chỉ.", "face":"happy" },
{ "text":"Tôi nghĩ bạn sẽ trở thành nông dân tuyệt vời.", "face":"happy" }

],


"heart6":[

{ "text":"Tôi thích nói chuyện với bạn.", "face":"shy" },
{ "text":"Bạn khiến tôi cảm thấy thoải mái.", "face":"shy" }

],


"heart8":[

{ "text":"Ở bên bạn khiến tôi thấy vui.", "face":"shy" },
{ "text":"Tôi luôn mong được gặp bạn.", "face":"happy" }

],


# ======================
# MARRIAGE
# ======================

"marry":[

{ "text":"Tôi rất hạnh phúc khi ở bên bạn.", "face":"marry" },
{ "text":"Chúng ta hãy cùng chăm sóc nông trại nhé.", "face":"marry" }

]

}
