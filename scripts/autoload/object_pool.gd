# ObjectPool 对象池：
# - 对子弹、掉落物等高频实例化对象做池化，减少 instantiate/queue_free 开销
# - acquire 从池中取或新建，recycle 回收到池，recycle_group 批量回收
extends Node

const POOL_META_KEY := "object_pool_scene_path"

# scene_path -> Array[Node]，池中空闲节点
var _pools: Dictionary = {}


## [自定义] 从池中获取或实例化节点，加入 parent，并设置池标识供 recycle 使用。
## 返回的节点需由调用方配置属性；回收时 bullet/pickup 会重置状态。
## deferred=true 时使用 call_deferred 加入 parent，避免 physics flushing 报错（如 wave_manager 掉落）。
func acquire(scene: PackedScene, parent: Node, deferred: bool = false) -> Node:
	if scene == null:
		return null
	var path: String = scene.resource_path
	var node: Node = null
	if _pools.has(path) and _pools[path].size() > 0:
		node = _pools[path].pop_back()
	if node == null:
		node = scene.instantiate()
	if node == null:
		return null
	node.set_meta(POOL_META_KEY, path)
	if deferred:
		parent.call_deferred("add_child", node)
	else:
		parent.add_child(node)
	return node


## [自定义] 将节点回收到池。
## 若节点带 pool_key 则回收，否则 queue_free（兼容非池化实例）。
func recycle(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var path: String = node.get_meta(POOL_META_KEY, "")
	if path == "":
		node.queue_free()
		return
	var parent: Node = node.get_parent()
	if parent == null:
		# 已脱离场景树，可能重复回收，忽略
		return
	parent.remove_child(node)
	if not _pools.has(path):
		_pools[path] = []
	_pools[path].append(node)
	# 若节点有 reset_for_pool 方法，调用以重置状态（如 bullet 清空 _hit_targets）
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()


## [自定义] 批量回收指定组内所有可池化节点。
func recycle_group(group_name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group_name):
		if is_instance_valid(node) and node.get_meta(POOL_META_KEY, "") != "":
			recycle(node)
