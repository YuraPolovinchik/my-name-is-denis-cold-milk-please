extends Node

signal call_updated(data: Dictionary)
signal question_started(text: String)
signal question_answered(reply: String)
signal question_missed()
signal subtitle_requested(text: String)

var active = false
var question_active = false
var time_to_question = 45.0
var answer_time_left = 0.0
var suspicion = 0
var question_kind: StringName = &"status"
var paused_for_rita := false
var _rng = RandomNumberGenerator.new()
var _question_index = 0
var _event_index = 0

const PAYMENT_AMOUNT := 900.0
const PAYMENT_PROMPT := "Денис, подтверждаете THE Платёж? Окно двенадцать секунд."

const QUESTIONS := [
    "Денис, вы с нами?",
    "Денис, какой у нас сейчас статус?",
    "Денис, можете коротко подсветить?",
    "Денис, у нас всё в работе?"
]

const REPLIES := [
    "Да, коллеги, здесь важно синхронизироваться.",
    "Давайте я отдельно уточню и вернусь.",
    "Сейчас на нашей стороне всё в работе.",
    "Предлагаю вынести это в отдельный слот."
]

func _process(delta: float) -> void:
    if not active or not RunStats.run_active:
        return
    paused_for_rita = RitaSleep.is_angry
    if paused_for_rita:
        call_updated.emit(get_state())
        return
    if question_active:
        answer_time_left -= delta
        if answer_time_left <= 0.0:
            _miss_question()
    else:
        time_to_question -= delta
        if time_to_question <= 0.0:
            _start_question()
    call_updated.emit(get_state())

func reset() -> void:
    _rng.seed = RunStats.seed_value
    active = true
    question_active = false
    time_to_question = _rng.randf_range(40.0, 55.0) / maxf(DifficultyManager.get_call_frequency(), 0.1)
    answer_time_left = 0.0
    suspicion = 0
    question_kind = &"status"
    paused_for_rita = false
    _question_index = 0
    _event_index = 0
    call_updated.emit(get_state())

func answer_question() -> String:
    if not question_active:
        return "Сейчас к Денису не обращаются."
    var reply: String
    if question_kind == &"payment":
        RunStats.receive_payment(PAYMENT_AMOUNT)
        reply = "THE ПЛАТЁЖ ПОДТВЕРЖДЁН. +%.0f ₽. Баланс: %.0f ₽." % [PAYMENT_AMOUNT, RunStats.money_balance]
        QuestManager.notification_requested.emit(reply)
    else:
        reply = REPLIES[_question_index % REPLIES.size()]
    question_active = false
    answer_time_left = 0.0
    time_to_question = _rng.randf_range(35.0, 70.0) / maxf(DifficultyManager.get_call_frequency(), 0.1)
    RunStats.answered_calls += 1
    NoiseManager.emit_noise(Vector3(-5.5, 1.2, -1.5), 11.0, &"VOICE_CALL", &"denis_reply")
    question_answered.emit(reply)
    subtitle_requested.emit(reply)
    call_updated.emit(get_state())
    return reply

func get_state() -> Dictionary:
    return {
        "active": active,
        "question_active": question_active,
        "time_to_question": maxf(time_to_question, 0.0),
        "answer_time_left": maxf(answer_time_left, 0.0),
        "suspicion": suspicion,
        "question_kind": String(question_kind),
        "paused_for_rita": paused_for_rita,
        "balance": RunStats.money_balance,
        "missed_payments": RunStats.missed_payments,
        "camera_warning": RunStats.camera_warning
    }

func _start_question() -> void:
    question_active = true
    answer_time_left = 12.0
    _event_index += 1
    question_kind = &"payment" if _event_index % 2 == 0 else &"status"
    var question: String
    if question_kind == &"payment":
        question = PAYMENT_PROMPT
    else:
        question = QUESTIONS[_question_index % QUESTIONS.size()]
        _question_index = (_question_index + 1) % QUESTIONS.size()
    question_started.emit(question)
    subtitle_requested.emit(question)
    NoiseManager.emit_noise(Vector3(-5.5, 1.2, -1.5), 14.0, &"VOICE_CALL", &"laptop")

func _miss_question() -> void:
    question_active = false
    RunStats.missed_calls += 1
    if question_kind == &"payment":
        var loss := RunStats.miss_payment()
        suspicion = mini(100, suspicion + 10)
        var miss_text := "БЫЛ THE ПЛАТЁЖ, ТЫ НЕ УСПЕЛ. −%.0f ₽. ЖДИ СЛЕДУЮЩИЙ." % loss
        subtitle_requested.emit(miss_text)
        QuestManager.notification_requested.emit(miss_text)
    else:
        suspicion = mini(100, suspicion + 25)
        subtitle_requested.emit("Денис?.. Вас не слышно.")
    time_to_question = _rng.randf_range(20.0, 38.0) / maxf(DifficultyManager.get_call_frequency(), 0.1)
    question_missed.emit()
    NoiseManager.emit_noise(Vector3(-5.5, 1.2, -1.5), 26.0, &"VOICE_CALL", &"laptop_missed")
    if suspicion >= 100:
        RunStats.camera_warning = true
        subtitle_requested.emit("ДЕНИС, ВКЛЮЧИТЕ КАМЕРУ")
