# ObjectPool 对象池：
# - 对子弹、掉落物、敌人等高频实例化对象做池化，减少 instantiate/queue_free 开销
# - acquire 从池中取或新建，recycle 回收到池，recycle_group 批量回收
# - 支持敌人类型池化，按 enemy_id 管理不同敌人类型
extends Node

const POOL_META_KEY := "object_pool_scene_path"
const POOL_TYPE_KEY := "object_pool_type"

# scene_path -> Array[Node]，池中空闲节点
var _pools: Dictionary = {}
# enemy_id -> Array[Node]，敌人类型池
var _enemy_pools: Dictionary = {}
# 池大小上限配置
const MAX_POOL_SIZE := 100


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


## [自定义] 从敌人池中获取或实例化敌人节点，按 enemy_id 分类管理。
## parent: 父节点；enemy_id: 敌人类型标识；scene: 敌人场景。
func acquire_enemy(enemy_id: String, scene: PackedScene, parent: Node, deferred: bool = false) -> Node:
	if scene == null or enemy_id == "":
		return null
	var node: Node = null
	
	# 尝试从对应 enemy_id 的池中获取
	if _enemy_pools.has(enemy_id) and _enemy_pools[enemy_id].size() > 0:
		node = _enemy_pools[enemy_id].pop_back()
		# 重置节点状态
		if node.has_method("reset_for_pool"):
			node.reset_for_pool()
	
	# 池中没有则新建
	if node == null:
		node = scene.instantiate()
		if node == null:
			return null
	
	# 设置池标识
	node.set_meta(POOL_TYPE_KEY, "enemy")
	node.set_meta(POOL_META_KEY, enemy_id)
	
	if deferred:
		parent.call_deferred("add_child", node)
	else:
		parent.add_child(node)
	return node


## [自定义] 将敌人回收到对应类型的池中。
func recycle_enemy(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var enemy_id: String = node.get_meta(POOL_META_KEY, "")
	if enemy_id == "" or node.get_meta(POOL_TYPE_KEY, "") != "enemy":
		node.queue_free()
		return
	
	var parent: Node = node.get_parent()
	if parent == null:
		return  # 已脱离场景树，可能重复回收
	
	parent.remove_child(node)
	
	# 限制池大小
	if not _enemy_pools.has(enemy_id):
		_enemy_pools[enemy_id] = []
	
	var pool: Array = _enemy_pools[enemy_id]
	if pool.size() < MAX_POOL_SIZE:
		pool.append(node)
		if node.has_method("reset_for_pool"):
			node.reset_for_pool()
	else:
		node.queue_free()


## [自定义] 批量回收所有敌人到对象池。
func recycle_all_enemies() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get_meta(POOL_TYPE_KEY, "") == "enemy":
			recycle_enemy(node)


## [自定义] 清空指定 enemy_id 的池，或清空所有敌人池。
func clear_enemy_pool(enemy_id: String = "") -> void:
	if enemy_id == "":
		# 清空所有敌人池
		for id in _enemy_pools.keys():
			for node in _enemy_pools[id]:
				if is_instance_valid(node):
					node.queue_free()
		_enemy_pools.clear()
	else:
		# 清空指定类型
		if _enemy_pools.has(enemy_id):
			for node in _enemy_pools[enemy_id]:
				if is_instance_valid(node):
					node.queue_free()
		_enemy_pools.erase(enemy_id)


## [自定义] 获取当前池状态统计（用于调试）。
func get_pool_stats() -> Dictionary:
	var stats := {"general": {}, "enemies": {}}
	for path in _pools.keys():
		stats["general"][path] = _pools[path].size()
	for enemy_id in _enemy_pools.keys():
		stats["enemies"][enemy_id] = _enemy_pools[enemy_id].size()
	return stats
