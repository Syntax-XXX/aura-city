class_name UIFormat
extends RefCounted
## Zahlen- und Zeitformatierung für die Oberfläche.


## 1234567 -> "1.234.567"; ab 10 Mio. kompakt ("12,3 Mio.").
static func number(value: float) -> String:
	var v := roundf(value)
	if absf(v) >= 10000000.0:
		return ("%.1f" % (v / 1000000.0)).replace(".", ",") + " Mio."
	var neg := v < 0.0
	var s := str(int(absf(v)))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


static func seconds(t: float) -> String:
	var s := int(maxf(0.0, t))
	return "%d:%02d" % [s / 60, s % 60]
