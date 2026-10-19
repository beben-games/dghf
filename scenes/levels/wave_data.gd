class_name WaveData
extends Resource
## One wave of a level (issue #62): how many of each kind of small fry. The
## kinds are spread through the wave, so it never arrives sorted.

@export var kinds: Array[CrowdKind] = []
@export var counts: PackedInt32Array = PackedInt32Array()

var _order: Array[CrowdKind] = []


func total() -> int:
	var n: int = 0
	for count in counts:
		n += count
	return n


## The kind of the `i`th body of the wave. The rarest kinds are placed first, each spread
## evenly over the wave, and the commonest fills what is left.
func kind_at(i: int) -> CrowdKind:
	if _order.size() != total():
		_order = _spread()
	return _order[i] if i < _order.size() else null


func _spread() -> Array[CrowdKind]:
	var n: int = total()
	var order: Array[CrowdKind] = []
	order.resize(n)
	var by_rarity: Array[int] = []
	for k in kinds.size():
		by_rarity.append(k)
	by_rarity.sort_custom(func(a: int, b: int) -> bool: return counts[a] < counts[b])
	for k in by_rarity:
		for j in counts[k]:
			var slot: int = int(floor((j + 0.5) * n / float(counts[k])))
			for step in n:
				var at: int = (slot + step) % n
				if order[at] == null:
					order[at] = kinds[k]
					break
	return order
