extends "res://addons/gut/test.gd"

func test_threshold_alarm_high_level_delay_and_deadband() -> void:
    var alarm: ThresholdAlarm = ThresholdAlarm.new()
    alarm.initialize({
        "alarm_id": &"ALARM_HIGH",
        "display_name": "High level alarm",
        "target_unit_id": &"BASIN_01",
        "target_property": "level_m",
        "alarm_type": "HIGH",
        "threshold_value": 9.0,
        "delay_s": 3.0,
        "deadband": 0.5,
        "message": "Basin high level!"
    })

    var context: SimulationContext = SimulationContext.new()
    context.current_tick = 1

    # Test 1: No violation
    alarm.evaluate(5.0, 1.0, context)
    assert_false(alarm.is_active)
    assert_eq(context.pending_events.size(), 0)

    # Test 2: Violation starts
    alarm.evaluate(9.1, 1.0, context)
    assert_false(alarm.is_active)
    assert_eq(alarm.violation_timer_s, 1.0)

    context.current_tick = 2
    alarm.evaluate(9.1, 1.0, context)
    assert_false(alarm.is_active)
    assert_eq(alarm.violation_timer_s, 2.0)

    context.current_tick = 3
    alarm.evaluate(9.1, 1.0, context)
    assert_true(alarm.is_active)
    assert_eq(context.pending_events.size(), 1, "Should emit AlarmActivated event")
    assert_eq(context.pending_events[0].event_type, &"AlarmActivated")
    assert_eq(context.pending_events[0].payload["alarm_id"], &"ALARM_HIGH")

    # Test 3: Stays active, no new events
    context.pending_events.clear()
    context.current_tick = 4
    alarm.evaluate(9.5, 1.0, context)
    assert_true(alarm.is_active)
    assert_eq(context.pending_events.size(), 0)

    # Test 4: Drops below threshold but inside deadband (8.8 > 8.5)
    context.current_tick = 5
    alarm.evaluate(8.8, 1.0, context)
    assert_true(alarm.is_active)
    assert_eq(context.pending_events.size(), 0)

    # Test 5: Drops below deadband (8.4 <= 8.5)
    context.current_tick = 6
    alarm.evaluate(8.4, 1.0, context)
    assert_false(alarm.is_active)
    assert_eq(context.pending_events.size(), 1, "Should emit AlarmCleared event")
    assert_eq(context.pending_events[0].event_type, &"AlarmCleared")

func test_low_alarm_delay_reset_deadband_and_single_events() -> void:
    var alarm := ThresholdAlarm.new()
    alarm.initialize({
        "alarm_id": "ALARM_LOW", "target_unit_id": "APPLIED_CHANNEL_01",
        "target_property": "level_m", "alarm_type": "LOW",
        "threshold_value": 0.5, "delay_s": 3.0, "deadband": 0.1
    })
    var context := SimulationContext.new()
    alarm.evaluate(0.4, 1.0, context)
    alarm.evaluate(0.5, 1.0, context)
    assert_eq(alarm.violation_timer_s, 0.0, "Returning to threshold resets a pending delay")
    alarm.evaluate(0.4, 1.0, context)
    alarm.evaluate(0.4, 1.0, context)
    assert_false(alarm.is_active, "Two seconds do not satisfy a three-second delay")
    assert_eq(context.pending_events.size(), 0)
    context.current_tick = 3
    alarm.evaluate(0.4, 1.0, context)
    assert_true(alarm.is_active)
    assert_eq(context.pending_events.size(), 1)
    assert_eq(context.pending_events[0].event_type, &"AlarmActivated")
    assert_eq(context.pending_events[0].tick, 3)
    context.pending_events.clear()
    alarm.evaluate(0.55, 1.0, context)
    assert_true(alarm.is_active, "A rise inside the deadband must not clear the alarm")
    alarm.evaluate(0.4, 1.0, context)
    assert_eq(context.pending_events.size(), 0, "An active alarm must not repeatedly activate")
    alarm.evaluate(0.6, 1.0, context)
    assert_false(alarm.is_active, "The clearing boundary is inclusive")
    assert_eq(context.pending_events.size(), 1)
    assert_eq(context.pending_events[0].event_type, &"AlarmCleared")
    context.pending_events.clear()
    alarm.evaluate(0.7, 1.0, context)
    assert_eq(context.pending_events.size(), 0, "A clear alarm must not repeatedly clear")
