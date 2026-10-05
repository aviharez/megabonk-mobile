class_name NodePool
extends RefCounted
## Pool of pre-made nodes (particles, short-lived visuals). All nodes are
## created up front under `parent`; when every node is busy, the oldest one is
## recycled, so the count never grows.

var nodes: Array[Node] = []
var _next := 0


func _init(parent: Node, size: int, factory: Callable) -> void:
	for i in size:
		var n: Node = factory.call()
		parent.add_child(n)
		nodes.append(n)


## Round-robin: hands out the least recently used node.
func take() -> Node:
	var n := nodes[_next]
	_next = (_next + 1) % nodes.size()
	return n
