extends SceneTree
## 离线切分 AI 透明图集并统一画布；原始生成图保持不变，碰撞不由图片推导。

## 生成图与切片资源的共同目录。
const ART_ROOT: String = "res://assets/art/painted_v1/"
## 比尔逐帧主体边界；生成图并非严格等距网格，必须按实际透明轮廓切分。
const BILL_RECTS: Array[Rect2i] = [
	Rect2i(54,31,276,309), Rect2i(399,34,309,306), Rect2i(768,36,304,303),
	Rect2i(1127,41,304,297), Rect2i(44,404,298,307), Rect2i(433,388,273,261),
	Rect2i(754,364,269,353), Rect2i(1111,388,303,329), Rect2i(25,906,411,133),
	Rect2i(438,749,270,289), Rect2i(749,746,296,295), Rect2i(1064,930,366,107)
]
## 洛克人逐帧主体边界，保留原始手绘透明边缘。
const MEGA_RECTS: Array[Rect2i] = [
	Rect2i(43,57,285,315), Rect2i(405,70,308,302), Rect2i(755,74,298,298),
	Rect2i(1103,72,310,299), Rect2i(36,426,312,308), Rect2i(398,394,296,302),
	Rect2i(705,451,380,283), Rect2i(1081,452,355,282), Rect2i(59,800,296,226),
	Rect2i(398,784,299,243), Rect2i(762,762,288,276), Rect2i(1068,881,353,138)
]
## 环境物件边界：地形、砖箱、平台、树与两种装饰蘑菇。
const ENV_RECTS: Array[Rect2i] = [
	Rect2i(24,71,340,309), Rect2i(398,90,298,291), Rect2i(740,83,319,297),
	Rect2i(1112,85,302,295), Rect2i(47,419,293,261), Rect2i(412,418,278,266),
	Rect2i(761,419,283,264), Rect2i(1092,502,342,126), Rect2i(14,693,403,354),
	Rect2i(388,810,332,231), Rect2i(736,719,355,327), Rect2i(1104,761,323,284)
]
## 环境纹理名称，与运行时画笔对应。
const ENV_NAMES: Array[String] = [
	"grass_top", "earth", "stone_top", "stone", "brick", "crate", "cracked",
	"platform", "tree", "flowers", "red_mushrooms", "purple_mushrooms"
]
## 五类怪物每种三态边界，按待机、攻击、受伤分行保存。
const ENEMY_RECTS: Array[Rect2i] = [
	Rect2i(20,137,246,185), Rect2i(350,149,276,170), Rect2i(628,47,373,282),
	Rect2i(981,107,279,225), Rect2i(1308,77,278,246),
	Rect2i(57,362,240,253), Rect2i(344,405,304,207), Rect2i(669,366,308,272),
	Rect2i(981,402,305,247), Rect2i(1311,364,286,266),
	Rect2i(68,681,235,225), Rect2i(383,718,257,182), Rect2i(676,705,281,200),
	Rect2i(993,711,273,198), Rect2i(1321,677,257,234)
]
## 敌人类别顺序，与图集列保持一致。
const ENEMY_NAMES: Array[String] = ["patrol", "spitter", "bat", "roller", "beetle"]
## 四个 Boss 状态的完整轮廓。
const BOSS_RECTS: Array[Rect2i] = [
	Rect2i(22,91,620,523), Rect2i(665,43,565,571),
	Rect2i(14,693,657,508), Rect2i(672,785,560,418)
]
## 道具与效果边界；冰晶保留小碎片，属于同一完整效果。
const ITEM_RECTS: Array[Rect2i] = [
	Rect2i(84,53,319,338), Rect2i(469,55,315,336), Rect2i(859,55,313,336),
	Rect2i(68,483,346,310), Rect2i(473,472,327,322), Rect2i(866,420,356,418),
	Rect2i(24,879,425,319), Rect2i(461,844,364,357), Rect2i(850,890,385,294)
]
## 道具名称对应运行时使用路径。
const ITEM_NAMES: Array[String] = ["capsule_s","capsule_l","capsule_f","heart",
	"ammo","flag","ice","cutter","fire"]


## 按确定边界切片；人物保持共同缩放和脚底锚点，运行时不再裁图。
func _initialize() -> void:
	# character 为本次处理的角色，每套使用自己的共同缩放倍率。
	for character: String in ["bill", "mega"]:
		# source 是带真实 alpha 的原始角色图集。
		var source: Image = Image.load_from_file(ART_ROOT + "sources/%s_sheet.png" % character)
		# rectangles 为已经查看过的逐帧边界。
		var rectangles: Array[Rect2i] = BILL_RECTS if character == "bill" else MEGA_RECTS
		# ratio 按待机身高计算，其他帧不单独拉伸，保持衣服、头与枪的比例。
		var ratio: float = 224.0 / (309.0 if character == "bill" else 315.0)
		# frame_index 为动画帧下标。
		for frame_index: int in range(rectangles.size()):
			# piece 为当前透明精灵，向外保留一像素的抗锯齿边缘。
			var piece: Image = source.get_region(rectangles[frame_index].grow(1))
			piece.resize(roundi(piece.get_width()*ratio), roundi(piece.get_height()*ratio),
				Image.INTERPOLATE_LANCZOS)
			# canvas 的锚点固定为 (128,272)，显示时缩小一半。
			var canvas: Image = Image.create(320, 288, false, Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(piece, Rect2i(Vector2i.ZERO,piece.get_size()),
				Vector2i(128-roundi(piece.get_width()*0.44),272-piece.get_height()))
			_save(canvas, "%s_%02d" % [character,frame_index])
	# environment 为环境原始图集。
	var environment: Image = Image.load_from_file(ART_ROOT + "sources/environment_sheet.png")
	# index 为对应名称与边界的共同下标。
	for index: int in range(ENV_RECTS.size()):
		_save(environment.get_region(ENV_RECTS[index]), ENV_NAMES[index])
	# enemies 为五怪原始图集。
	var enemies: Image = Image.load_from_file(ART_ROOT + "sources/enemies_sheet.png")
	# index 按每行五个怪物切分，不把动作行混入其他种类。
	for index: int in range(ENEMY_RECTS.size()):
		_save(enemies.get_region(ENEMY_RECTS[index]),
			"%s_%d" % [ENEMY_NAMES[index%5],index/5])
	# boss 为 Boss 图集；固定画布与倍率使脚底、核心和拳头位置稳定。
	var boss: Image = Image.load_from_file(ART_ROOT + "sources/boss_sheet.png")
	# index 为四种独立动作。
	for index: int in range(BOSS_RECTS.size()):
		# piece 是 Boss 当前完整状态。
		var piece: Image = boss.get_region(BOSS_RECTS[index])
		piece.resize(roundi(piece.get_width()*0.62),roundi(piece.get_height()*0.62),
			Image.INTERPOLATE_LANCZOS)
		# canvas 统一宽度，脚底位于 (240,376)。
		var canvas: Image = Image.create(480,400,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),
			Vector2i(240-piece.get_width()/2,376-piece.get_height()))
		_save(canvas,"boss_%d" % index)
	# items 为道具原始图集。
	var items: Image = Image.load_from_file(ART_ROOT + "sources/items_sheet.png")
	# index 为道具切片顺序。
	for index: int in range(ITEM_RECTS.size()):
		_save(items.get_region(ITEM_RECTS[index]),ITEM_NAMES[index])
	print("PAINTED ART: 64 transparent slices prepared")
	quit()


## image 为透明切片，name 为稳定文件名；保存失败会立刻报告。
func _save(image: Image, name: String) -> void:
	assert(image.save_png(ART_ROOT + name + ".png") == OK, "美术切片保存失败: " + name)
