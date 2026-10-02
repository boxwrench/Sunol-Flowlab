class_name AlarmPanel
extends PanelContainer

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var alarm_list: Label = $VBoxContainer/AlarmList

var _engine: SimulationEngine = null
var displayed_tick: int = -1

func configure(engine: SimulationEngine) -> void:
    _engine = engine

func refresh_from_snapshot() -> void:
    if _engine == null or _engine.latest_snapshot.is_empty():
        return
    apply_snapshot(_engine.latest_snapshot)

func apply_snapshot(snapshot: Dictionary) -> void:
    # Read status only from the published snapshot. Text and symbols carry state;
    # color supplements active alarms and never implies a hydraulic calculation.
    var alarms: Dictionary = snapshot.get("alarms", {})
    var alarm_ids: Array = alarms.keys()
    alarm_ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
    var rows: PackedStringArray = []
    var active_count := 0
    for alarm_id in alarm_ids:
        var alarm: Dictionary = alarms[alarm_id]
        var active: bool = bool(alarm.get("is_active", false))
        if active:
            active_count += 1
        var status := "[!] ACTIVE" if active else "[OK] CLEAR"
        rows.append("%s: %s" % [status, alarm.get("display_name", String(alarm_id))])
    displayed_tick = int(snapshot.get("tick", 0))
    title_label.text = "Alarms: %d active | Tick: %d" % [active_count, displayed_tick]
    alarm_list.text = "\n".join(rows) if not rows.is_empty() else "No configured alarms"
    title_label.modulate = Color(1.0, 0.75, 0.35) if active_count > 0 else Color(0.85, 0.87, 0.90)

func _process(_delta: float) -> void:
    refresh_from_snapshot()
