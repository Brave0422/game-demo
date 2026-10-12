class_name PaintedArt
extends RefCounted
## 手绘资源统一缓存与画笔；只负责呈现，物理状态与碰撞由原有场景控制。

## 纹理缓存防止逐帧重复加载，最终切片均保存在项目内。
static var _textures: Dictionary = {}


## name 为美术文件名；首次使用时加载并复用已导入的纹理。
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/art/painted_v1/%s.png" % name)
	return _textures[name]


## canvas、name、rect、tint 为画布、资源名、目标矩形和调制色；不改变锚点。
static func draw(canvas: CanvasItem, name: String, rect: Rect2,
		tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect(texture(name), rect, false, tint)


## origin 为脚底，height 为显示高度；保持装饰原始宽高比。
static func decoration(canvas: CanvasItem, name: String, origin: Vector2, height: float,
		tint: Color = Color.WHITE) -> void:
	# image 为已经导入的装饰纹理。
	var image: Texture2D = texture(name)
	# width 由源比例计算，防止树木或菌盖被横向压扁。
	var width: float = height * image.get_width() / image.get_height()
	canvas.draw_texture_rect(image, Rect2(origin-Vector2(width*0.5,height),
		Vector2(width,height)), false, tint)
