class_name Num
extends RefCounted
## The one way numbers are written on screen (phase 14).
##
## full():  menus, where the line can grow: "9,876,543".
## short(): fixed spaces (HUD, stat tiles, coin plates in tight rows, stack
##          badges, prices on map labels): never more than 5 characters,
##          "9,999", "12.3K", "999K", "1.2M", "12M".
## tiny():  damage numbers in a crowd: never more than 4 characters,
##          "999", "1.2K", "12K", "123K", "1.2M".
## Short forms round down, so they never show more than there is
## (999,999 is "999K", not "1M").

const SUFFIXES := ["", "K", "M", "B", "T"]


## "1246" -> "1,246".
static func full(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


static func short(n: int) -> String:
	if absi(n) < 10000:
		return full(n)
	return _scaled(n, 100)


static func tiny(n: int) -> String:
	if absi(n) < 1000:
		return str(n)
	return _scaled(n, 10)


## 12345 -> "12.3K", 123456 -> "123K", 1234567 -> "1.2M": one decimal while
## below `decimal_below` of a unit (digits after it are dropped, not rounded).
static func _scaled(n: int, decimal_below: int) -> String:
	var v := absi(n)
	var unit := 0
	while v >= 1000 and unit < SUFFIXES.size() - 1:
		v /= 1000
		unit += 1
	var whole := absi(n) / int(pow(1000, unit))
	var text := str(whole)
	if whole < decimal_below:
		var tenth := (absi(n) / int(pow(1000, unit) / 10)) % 10
		if tenth > 0:
			text += "." + str(tenth)
	return ("-" if n < 0 else "") + text + SUFFIXES[unit]

