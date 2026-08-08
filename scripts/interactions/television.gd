extends "res://scripts/interactions/physical_item.gd"

const LOCAL_FOOTBALL_VIDEO := "res://assets/football_video.ogv"
const WEB_FOOTBALL_VIDEO := "res://assets/football_video_web.ogv"
const RITA_MOVIE_SECONDS := 14.0
const RITA_VIEW_POINT := Vector3(-6.45, 1.0, 4.70)
const INTERACTION_QUIET := 1

var plugged := false
var powered := false
var _watch_timer := 18.0
var _watch_deadline := 0.0
var _watch_required := false
var _score_home := 0
var _score_away := 0
var _screen: MeshInstance3D
var _screen_fallback_material: StandardMaterial3D
var _video_material: ShaderMaterial
var _score_label: Label3D
var _ball: MeshInstance3D
var _phase := 0.0
var _video_player: VideoStreamPlayer
var _video_viewport: SubViewport
var _using_real_video := false
var muted := false
var _tv_noise_timer := 1.2
var _movie_progress := 0.0
var _movie_ready_last_frame := false

func _ready() -> void:
    collision_layer = 2
    collision_mask = 3
    continuous_cd = true
    axis_lock_angular_x = true
    axis_lock_angular_z = true
    freeze = true
    super._ready()
    add_to_group("television")
    add_to_group("festival_tv_task")

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    var outlet := _nearest_outlet(2.8)
    if plugged and outlet == null:
        _miss_active_moment("ВИЛКА ВЫДЕРНУТА ВО ВРЕМЯ МОМЕНТА  •  СИЛЫ −16")
        plugged = false
        powered = false
        QuestManager.notification_requested.emit("ВИЛКА ВЫДЕРНУТА. ТЕЛЕВИЗОР ПОГАС")
    _process_tv_noise(delta)
    if RitaDemands.active_type == &"festival_cinema":
        _process_festival_movie(delta)
        _update_screen()
        return
    if not powered:
        return
    _phase += delta
    if _ball != null:
        _ball.position.x = sin(_phase * 2.4) * 0.48
        _ball.position.y = cos(_phase * 3.1) * 0.13
    _watch_timer -= delta
    if not _watch_required and _watch_timer <= 0.0:
        if _pressure_busy():
            _watch_timer = 2.5
            return
        _watch_required = true
        _watch_deadline = 12.0
        QuestManager.set_bonus_objective(&"football", "ПОДГЛЯДЕТЬ ЗА ФУТБОЛОМ И СДЕЛАТЬ ГЛОТОК ПИВА")
        QuestManager.notification_requested.emit("ОПАСНЫЙ МОМЕНТ! ФУТБОЛ ВЕРНЁТ СИЛЫ, ПИВО — БЫСТРЕЕ")
    if _watch_required:
        if RitaSleep.is_angry or RitaDemands.has_active_demand() or CallManager.question_active:
            return
        _watch_deadline -= delta
        if _watch_deadline <= 0.0:
            _miss_active_moment("ПРОПУСТИЛ ОПАСНЫЙ МОМЕНТ  •  УПАДОК СИЛ −16")

func interact(actor, mode: int) -> String:
    if held:
        return "СНАЧАЛА ПОСТАВЬ ТЕЛЕВИЗОР"
    if plugged and mode == INTERACTION_QUIET:
        return _toggle_mute()
    var outlet := _nearest_outlet(2.8)
    if not plugged:
        if outlet == null:
            return "РЯДОМ НЕТ РОЗЕТКИ"
        plugged = true
        powered = true
        _watch_timer = minf(_watch_timer, 12.0)
        _update_screen()
        AudioManager.play_3d(&"switch", global_position, -8.0)
        if RitaDemands.active_type == &"festival_cinema":
            return "ТЕЛЕВИЗОР ВКЛЮЧЁН  •  ПОСТАВЬ ЕГО ПЕРЕД РИТОЙ И СТОЙ РЯДОМ"
        return "ТЕЛЕВИЗОР ВКЛЮЧЁН. ИДЁТ ФУТБОЛ"
    if RitaDemands.active_type == &"festival_cinema":
        if not powered:
            powered = true
            _update_screen()
            return "ТЕЛЕВИЗОР ВКЛЮЧЁН ДЛЯ РИТЫ"
        return "ЯПОНСКОЕ КИНО ИДЁТ  •  НЕ ОТХОДИ, ПОКА РИТА НЕ УСНЁТ"
    if _watch_required:
        return _complete_watch(actor, _nearest_match_beer(3.4))
    powered = not powered
    if not powered:
        _miss_active_moment("ВЫКЛЮЧИЛ ТВ ВО ВРЕМЯ МОМЕНТА  •  СИЛЫ −16")
    _update_screen()
    AudioManager.play_3d(&"switch", global_position, -9.0)
    return "ТЕЛЕВИЗОР %s" % ("ВКЛЮЧЁН" if powered else "ВЫКЛЮЧЕН")

func get_prompt(_actor) -> String:
    if plugged:
        var mute_hint := "ВКЛЮЧИТЬ" if muted else "ВЫКЛЮЧИТЬ"
        if RitaDemands.active_type == &"festival_cinema":
            return "КИНО РИТЫ • УДЕРЖИВАТЬ E — ЗВУК %s" % mute_hint
        if _watch_required:
            return "ПОДГЛЯДЕТЬ МОМЕНТ | УДЕРЖИВАТЬ E — ЗВУК %s | ЛКМ — ВЗЯТЬ ТВ" % mute_hint
        return "ВКЛ/ВЫКЛ ТЕЛЕВИЗОР | УДЕРЖИВАТЬ E — ЗВУК %s | ЛКМ — ВЗЯТЬ ТВ" % mute_hint
    if RitaDemands.active_type == &"festival_cinema":
        if held:
            return "ОТНЕСИ ТЕЛЕВИЗОР В СПАЛЬНЮ РИТЫ"
        if not plugged:
            return "ВКЛЮЧИТЬ ТВ В РОЗЕТКУ ДЛЯ РИТЫ | ЛКМ — ВЗЯТЬ"
        return "КИНО РИТЫ  •  СТОЙ РЯДОМ ДО КОНЦА"
    if not plugged:
        return "ВКЛЮЧИТЬ В БЛИЖАЙШУЮ РОЗЕТКУ | ЛКМ — ВЗЯТЬ ТВ"
    if _watch_required:
        return "ПОДГЛЯДЕТЬ ОПАСНЫЙ МОМЕНТ | ЛКМ — ВЗЯТЬ ТВ"
    return "ВКЛ/ВЫКЛ ТЕЛЕВИЗОР | ЛКМ — ВЗЯТЬ ТВ"

func connect_to_outlet(outlet: Node3D) -> String:
    if outlet == null or _planar_distance(global_position, outlet.global_position) > 2.8:
        return "ТЕЛЕВИЗОР СЛИШКОМ ДАЛЕКО ОТ РОЗЕТКИ"
    plugged = true
    powered = true
    _watch_timer = minf(_watch_timer, 12.0)
    _update_screen()
    AudioManager.play_3d(&"switch", global_position, -8.0)
    QuestManager.notification_requested.emit("ТЕЛЕВИЗОР ПОДКЛЮЧЁН. ИДЁТ ФУТБОЛ")
    return "ТЕЛЕВИЗОР ПОДКЛЮЧЁН К РОЗЕТКЕ"

func on_released() -> void:
    super.on_released()
    call_deferred("_auto_connect")

func _auto_connect() -> void:
    var outlet := _nearest_outlet(2.8)
    if outlet != null:
        connect_to_outlet(outlet)

func on_picked_up() -> void:
    if plugged:
        _miss_active_moment("УНЁС ТЕЛЕВИЗОР ВО ВРЕМЯ МОМЕНТА  •  СИЛЫ −16")
        plugged = false
        powered = false
    super.on_picked_up()
    _update_screen()

func complete_watch_with_beer(actor, beer) -> String:
    if not powered:
        return "ТЕЛЕВИЗОР НЕ ВКЛЮЧЁН"
    if _watch_required:
        return _complete_watch(actor, beer)
    if beer == null or not is_instance_valid(beer) or not beer.has_method("take_sip"):
        return "ПИВО НЕ НАЙДЕНО"
    return "СМОТРИШЬ МАТЧ  •  %s" % String(beer.call("take_sip", actor))

func _complete_watch(actor, beer: Node3D) -> String:
    _watch_required = false
    _watch_timer = randf_range(24.0, 38.0)
    _score_home += 1 if randf() > 0.45 else 0
    _score_away += 1 if randf() > 0.72 else 0
    QuestManager.clear_bonus_objective(&"football")
    var drank_beer := false
    var beer_text := "БЕЗ ПИВА — ТОЛЬКО КОРОТКАЯ ПЕРЕДЫШКА"
    if beer != null and is_instance_valid(beer) and beer.has_method("take_sip"):
        var before_sips := int(beer.get("sips_remaining"))
        beer_text = String(beer.call("take_sip", actor))
        drank_beer = int(beer.get("sips_remaining")) < before_sips
    if actor != null and is_instance_valid(actor) and actor.has_method("on_match_watched"):
        actor.call("on_match_watched", drank_beer)
    RunStats.record_football_moment(true)
    _update_screen()
    return "ПОДГЛЯДЕЛ: ОПАСНЫЙ МОМЕНТ! СЧЁТ %d:%d  •  %s" % [_score_home, _score_away, beer_text]

func _miss_active_moment(message: String) -> void:
    if not _watch_required:
        return
    _watch_required = false
    _watch_timer = randf_range(24.0, 38.0)
    QuestManager.clear_bonus_objective(&"football")
    var player := get_tree().get_first_node_in_group("player")
    if player != null and player.has_method("on_match_missed"):
        player.call("on_match_missed")
    RunStats.record_football_moment(false)
    QuestManager.notification_requested.emit(message)

func configure_visuals(screen: MeshInstance3D, score_label: Label3D, ball: MeshInstance3D) -> void:
    _screen = screen
    if _screen.material_override != null:
        _screen_fallback_material = _screen.material_override.duplicate() as StandardMaterial3D
        _screen.material_override = _screen_fallback_material
    _score_label = score_label
    _ball = ball
    _setup_optional_video()
    if _using_real_video:
        var video_shader := Shader.new()
        video_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D video_texture : source_color, filter_linear;
void fragment() {
    ALBEDO = texture(video_texture, UV).rgb;
}
"""
        _video_material = ShaderMaterial.new()
        _video_material.shader = video_shader
    _update_screen()

func _setup_optional_video() -> void:
    var video_path := WEB_FOOTBALL_VIDEO if OS.has_feature("web") else LOCAL_FOOTBALL_VIDEO
    if not ResourceLoader.exists(video_path):
        return
    var loaded_stream := load(video_path) as VideoStream
    if loaded_stream == null:
        push_warning("football.ogv exists but Godot could not load it as VideoStream")
        return
    _video_viewport = SubViewport.new()
    _video_viewport.name = "FootballVideoViewport"
    _video_viewport.size = Vector2i(854, 480)
    _video_viewport.disable_3d = true
    _video_viewport.transparent_bg = false
    _video_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_video_viewport)
    _video_player = VideoStreamPlayer.new()
    _video_player.name = "FootballVideoPlayer"
    _video_player.stream = loaded_stream
    _video_player.loop = true
    _video_player.autoplay = false
    _video_player.expand = true
    _video_player.position = Vector2.ZERO
    _video_player.size = Vector2(854.0, 480.0)
    _video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _video_viewport.add_child(_video_player)
    _apply_mute_state()
    _using_real_video = true

func _update_screen() -> void:
    var festival_movie := RitaDemands.active_type == &"festival_cinema"
    if _screen != null:
        var video_texture := _video_viewport.get_texture() if powered and _using_real_video and not festival_movie and _video_viewport != null else null
        if video_texture != null and _video_material != null:
            _video_material.set_shader_parameter("video_texture", video_texture)
            _screen.material_override = _video_material
        else:
            _screen.material_override = _screen_fallback_material
        var material := _screen_fallback_material
        if material != null and video_texture == null:
            material.albedo_color = Color("7f638f") if powered and festival_movie else (Color.WHITE if powered and _using_real_video else (Color("4b8d58") if powered else Color("182229")))
            material.albedo_texture = null
            material.emission_enabled = powered
            material.emission_texture = null
            material.emission = Color("7f638f") if festival_movie else Color("4b8d58")
    if _video_player != null:
        _apply_mute_state()
        if powered and not festival_movie and not _video_player.is_playing():
            _video_player.play()
        elif (not powered or festival_movie) and _video_player.is_playing():
            _video_player.stop()
    if _score_label != null:
        _score_label.visible = not (powered and _using_real_video and not festival_movie)
        if powered and festival_movie:
            _score_label.text = "ЯПОНСКОЕ ФЕСТИВАЛЬНОЕ КИНО\nТИХАЯ НОЧЬ В КИОТО  •  %d%%" % int(_movie_progress)
        else:
            _score_label.text = ("LIVE  ФУТБОЛ\nДЕНИС ЮНАЙТЕД  %d : %d  РИТА СИТИ" % [_score_home, _score_away]) if powered else "НЕТ ПИТАНИЯ"
    if _ball != null:
        _ball.visible = powered and not _using_real_video and not festival_movie
    var pitch := get_node_or_null("Pitch") as MeshInstance3D
    if pitch != null:
        pitch.visible = powered and not _using_real_video and not festival_movie

func _toggle_mute() -> String:
    muted = not muted
    _apply_mute_state()
    _tv_noise_timer = 0.35
    AudioManager.play_3d(&"switch", global_position, -12.0)
    return "ТЕЛЕВИЗОР: ЗВУК %s" % ("ВЫКЛЮЧЕН — РИТА НЕ СЛЫШИТ МАТЧ" if muted else "ВКЛЮЧЁН — ЭТО РАЗБУДИТ РИТУ")

func _apply_mute_state() -> void:
    if _video_player != null:
        _video_player.volume_db = -80.0 if muted else -13.0

func _process_tv_noise(delta: float) -> void:
    if not powered or muted or held:
        _tv_noise_timer = minf(_tv_noise_timer, 0.35)
        return
    _tv_noise_timer -= delta
    if _tv_noise_timer <= 0.0:
        _tv_noise_timer = 2.0
        NoiseManager.emit_noise(global_position, 6.5, &"MEDIA", &"television")

func _process_festival_movie(delta: float) -> void:
    if bool(get_meta("freeze_movie_progress", false)):
        return
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var television_ready := powered and not held and NoiseManager.room_for_position(global_position) == &"bedroom" and global_position.distance_to(RITA_VIEW_POINT) <= 5.2
    if television_ready and not RitaDemands.is_festival_movie_watching():
        RitaDemands.begin_festival_movie()
    if not RitaDemands.is_festival_movie_watching():
        _movie_ready_last_frame = television_ready
        return
    var player_standing_near := player != null and not bool(player.get("is_hidden")) and player.global_position.distance_to(global_position) <= 3.0
    if television_ready and player_standing_near:
        _movie_progress = minf(100.0, _movie_progress + delta / RITA_MOVIE_SECONDS * 100.0)
    else:
        _movie_progress = maxf(0.0, _movie_progress - delta * 2.5)
        if _movie_ready_last_frame and not television_ready:
            QuestManager.notification_requested.emit("КИНО ПРЕРВАНО  •  ВЕРНИ ТЕЛЕВИЗОР И ПИТАНИЕ")
    _movie_ready_last_frame = television_ready
    RitaDemands.set_festival_progress(_movie_progress)
    if _movie_progress >= 100.0:
        var result := RitaDemands.try_complete_at(&"rita_tv_watch")
        QuestManager.notification_requested.emit(result)
        _movie_progress = 0.0
        _update_screen()

func get_task_state() -> Dictionary:
    if not RitaDemands.is_festival_movie_watching():
        return {"active": false}
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var television_ready := powered and not held and NoiseManager.room_for_position(global_position) == &"bedroom" and global_position.distance_to(RITA_VIEW_POINT) <= 5.2
    var player_near := player != null and player.global_position.distance_to(global_position) <= 3.0
    var hint := "СТОЙ РЯДОМ  •  РИТА ПОСТЕПЕННО ЗАСЫПАЕТ"
    if not television_ready:
        hint = "КИНО НА ПАУЗЕ  •  ТВ ДОЛЖЕН БЫТЬ В СПАЛЬНЕ И В РОЗЕТКЕ"
    elif not player_near:
        hint = "КИНО НА ПАУЗЕ  •  ДЕНИС ДОЛЖЕН СТОЯТЬ РЯДОМ"
    return {"active": true, "label": "РИТА СМОТРИТ ЯПОНСКОЕ КИНО", "progress": _movie_progress, "skill": false, "hint": hint}

func _nearest_outlet(radius: float) -> Node3D:
    var nearest: Node3D = null
    var best := radius
    for node in get_tree().get_nodes_in_group("power_outlet"):
        if node is Node3D:
            var distance := _planar_distance(global_position, (node as Node3D).global_position)
            if distance <= best:
                best = distance
                nearest = node
    return nearest

func _nearest_match_beer(radius: float) -> Node3D:
    var nearest: Node3D
    var best := radius
    for node in get_tree().get_nodes_in_group("match_beer"):
        if node is Node3D:
            var distance := global_position.distance_to((node as Node3D).global_position)
            if distance <= best:
                nearest = node
                best = distance
    return nearest

func _planar_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()

func _pressure_busy() -> bool:
    if RitaSleep.is_angry or RitaDemands.has_active_demand() or CallManager.question_active:
        return true
    for hazard in get_tree().get_nodes_in_group("household_hazards"):
        if bool(hazard.get("active")):
            return true
    return false
