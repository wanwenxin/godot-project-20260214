extends RefCounted
class_name AffixComboDefs

# 词条组合效果配置：当玩家同时拥有指定词条组合时，触发额外效果。
# 后续按需扩展：在此定义组合规则，由 AffixManager.check_combos 调用。
# 示例格式：{"affix_ids": ["item_lifesteal", "item_melee"], "combo_id": "vampire_warrior", "bonus": {...}}

const COMBO_POOL: Array = []
