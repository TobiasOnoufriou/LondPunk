class_name CombatHUD
extends CanvasLayer
## Combat UI: turn order, party health, ability bar, combat log and result screen.
##
## Hidden outside combat. Driven entirely by EventBus. It only reads state from the units passed in
## signal payloads, and sends the player's requests back as EventBus signals;
## it never commands units directly.

const MAX_LOG_LINES: int = 40
const HOTKEY_COUNT: int = 4
const DEAD_COLOR: Color = Color(0.4, 0.4, 0.4)

@export var round_label: Label
@export var turn_order_bar: HBoxContainer
@export var party_list: VBoxContainer
@export var bottom_panel: Control
@export var active_name_label: Label
@export var ap_label: Label
@export var ability_bar: HBoxContainer
@export var end_turn_button: Button
@export var log_label: RichTextLabel
@export var result_panel: Control
@export var result_label: Label
@export var restart_button: Button

var _active: Combatant
var _armed: Ability
var _current_ap: int = 0
var _busy: bool = false
var _ability_buttons: Dictionary[Ability, Button] = {}
var _order_labels: Dictionary[Combatant, Label] = {}
var _party_labels: Dictionary[Combatant, Label] = {}
var _party_bars: Dictionary[Combatant, ProgressBar] = {}
var _log_lines: PackedStringArray = PackedStringArray()
var _party_won: bool = false


func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_order_changed.connect(_on_turn_order_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.ap_changed.connect(_on_ap_changed)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.status_changed.connect(_on_status_changed)
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.ability_armed.connect(_on_ability_armed)
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.combat_log_message.connect(_on_combat_log_message)

	end_turn_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.pressed.connect(EventBus.end_turn_requested.emit)
	restart_button.pressed.connect(_on_result_button_pressed)
	bottom_panel.hide()
	result_panel.hide()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_player_turn():
		return
	if event.is_action_pressed("end_turn"):
		EventBus.end_turn_requested.emit()
	elif event.is_action_pressed("cancel_ability"):
		EventBus.ability_cancelled.emit()
	else:
		var abilities: Array[Ability] = _active.stats.abilities
		for i: int in mini(HOTKEY_COUNT, abilities.size()):
			if event.is_action_pressed("ability_%d" % (i + 1)):
				EventBus.ability_selected.emit(abilities[i])
				break
		return
	get_viewport().set_input_as_handled()


func _is_player_turn() -> bool:
	return _active != null and _active.faction == Combatant.Faction.PARTY


# --- Ability bar ---

func _build_ability_bar() -> void:
	_clear_ability_bar()
	var abilities: Array[Ability] = _active.stats.abilities
	for i: int in abilities.size():
		var ability: Ability = abilities[i]
		var button: Button = Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		var hotkey: String = "%d. " % (i + 1) if i < HOTKEY_COUNT else ""
		button.text = "%s%s (%s)" % [hotkey, ability.display_name, ability.get_cost_label()]
		button.tooltip_text = ability.description
		button.pressed.connect(_on_ability_button_pressed.bind(ability))
		ability_bar.add_child(button)
		_ability_buttons[ability] = button
	_refresh_buttons()


func _clear_ability_bar() -> void:
	for button: Button in _ability_buttons.values():
		button.queue_free()
	_ability_buttons.clear()


func _refresh_buttons() -> void:
	for ability: Ability in _ability_buttons:
		var button: Button = _ability_buttons[ability]
		button.disabled = _busy or ability.ap_cost > _current_ap
		button.set_pressed_no_signal(ability == _armed)
	end_turn_button.disabled = _busy


func _update_ap_label(maximum: int) -> void:
	ap_label.text = "AP  %s%s  %d/%d" % [
		"●".repeat(_current_ap), "○".repeat(maxi(maximum - _current_ap, 0)), _current_ap, maximum]


# --- Turn order & party panel ---

func _refresh_order_highlight() -> void:
	for unit: Combatant in _order_labels:
		var label: Label = _order_labels[unit]
		label.text = ("▶ %s" if unit == _active else "%s") % unit.get_display_name()
		label.modulate = unit.stats.color if unit.is_alive() else DEAD_COLOR


func _update_party_row(unit: Combatant) -> void:
	if not _party_labels.has(unit):
		return
	var text: String = "%s  %d/%d" % [unit.get_display_name(), unit.health.current_hp, unit.health.max_hp]
	for status: StatusEffect in unit.statuses:
		text += "  [%s]" % status.display_name
	_party_labels[unit].text = text
	_party_labels[unit].modulate = Color.WHITE if unit.is_alive() else DEAD_COLOR
	_party_bars[unit].max_value = unit.health.max_hp
	_party_bars[unit].value = unit.health.current_hp


## Clears everything left over from a previous fight.
func _reset() -> void:
	_active = null
	_armed = null
	_busy = false
	_clear_ability_bar()
	for child: Node in party_list.get_children():
		child.queue_free()
	_party_labels.clear()
	_party_bars.clear()
	for label: Label in _order_labels.values():
		label.queue_free()
	_order_labels.clear()
	_log_lines.clear()
	log_label.text = ""
	round_label.text = ""
	bottom_panel.hide()
	result_panel.hide()


# --- EventBus handlers ---

func _on_combat_started(combatants: Array[Combatant]) -> void:
	_reset()
	show()
	for unit: Combatant in combatants:
		if unit.faction != Combatant.Faction.PARTY:
			continue
		var label: Label = Label.new()
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 8.0)
		bar.modulate = unit.stats.color
		party_list.add_child(label)
		party_list.add_child(bar)
		_party_labels[unit] = label
		_party_bars[unit] = bar
		_update_party_row(unit)


func _on_combat_ended(party_won: bool) -> void:
	_active = null
	_clear_ability_bar()
	bottom_panel.hide()
	_party_won = party_won
	result_label.text = "VICTORY" if party_won else "DEFEAT"
	restart_button.text = "Continue" if party_won else "Restart"
	result_panel.show()


func _on_round_started(round_number: int) -> void:
	round_label.text = "Round %d" % round_number


func _on_turn_order_changed(order: Array[Combatant]) -> void:
	for label: Label in _order_labels.values():
		label.queue_free()
	_order_labels.clear()
	for unit: Combatant in order:
		var label: Label = Label.new()
		turn_order_bar.add_child(label)
		_order_labels[unit] = label
	_refresh_order_highlight()


func _on_turn_started(unit: Combatant) -> void:
	_active = unit
	_armed = null
	_busy = false
	_current_ap = unit.action_points.current_ap
	_refresh_order_highlight()

	var is_party: bool = unit.faction == Combatant.Faction.PARTY
	active_name_label.text = unit.get_display_name() if is_party else "Enemy turn: %s" % unit.get_display_name()
	ability_bar.visible = is_party
	end_turn_button.visible = is_party
	_update_ap_label(unit.action_points.max_ap)
	if is_party:
		_build_ability_bar()
	else:
		_clear_ability_bar()
	bottom_panel.show()


func _on_turn_ended(unit: Combatant) -> void:
	if unit != _active:
		return
	_active = null
	_clear_ability_bar()
	_refresh_order_highlight()


func _on_ap_changed(unit: Combatant, current: int, maximum: int) -> void:
	if unit != _active:
		return
	_current_ap = current
	_update_ap_label(maximum)
	_refresh_buttons()


func _on_hp_changed(unit: Combatant, _current: int, _maximum: int) -> void:
	_update_party_row(unit)


func _on_status_changed(unit: Combatant) -> void:
	_update_party_row(unit)


func _on_combatant_died(unit: Combatant) -> void:
	_update_party_row(unit)
	_refresh_order_highlight()


func _on_ability_armed(_user: Combatant, ability: Ability) -> void:
	_armed = ability
	_refresh_buttons()


func _on_ability_used(_user: Combatant, _ability: Ability, _target: AbilityTarget) -> void:
	_busy = true
	_refresh_buttons()


func _on_action_resolved(_user: Combatant) -> void:
	_busy = false
	_refresh_buttons()


func _on_combat_log_message(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines = _log_lines.slice(_log_lines.size() - MAX_LOG_LINES)
	log_label.text = "\n".join(_log_lines)


func _on_ability_button_pressed(ability: Ability) -> void:
	EventBus.ability_selected.emit(ability)
	# Toggle buttons flip themselves on click; snap back to the real armed state.
	_refresh_buttons()


func _on_result_button_pressed() -> void:
	_reset()
	hide()
	# On defeat SaveManager rolls back to its pre-fight checkpoint.
	EventBus.combat_result_acknowledged.emit(_party_won)
