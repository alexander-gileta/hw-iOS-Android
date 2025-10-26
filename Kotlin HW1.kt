import java.text.SimpleDateFormat
import java.util.*

interface IdentifiableModel {
    val id: Int
}

class Storage<T : IdentifiableModel> {
    private val storage = mutableListOf<T>()

    fun add(item: T) {
        removeById(item.id)
        storage.add(item)
    }

    fun remove(item: T) {
        removeById(item.id)
    }

    fun removeById(id: Int) {
        storage.removeAll { it.id == id }
    }

    fun getAll(): List<T> = storage.toList()

    fun getValueById(id: Int): T? = storage.firstOrNull { it.id == id }

    fun clear() {
        storage.clear()
    }
}

interface CanvasUnit {
    fun drawCanvas(): String
}

interface AnyNote : CanvasUnit {
    fun willRemove()
}

open class Note<Data : IdentifiableModel>(var data: Data) : AnyNote {
    val storage = Storage<Data>()

    init {
        storage.add(data)
    }

    open fun update(newData: Data) {
        data = newData
        storage.add(data)
    }

    override fun willRemove() {
        storage.clear()
    }

    override fun drawCanvas(): String {
        return "Заметка, id: ${data.id}"
    }
}

interface TimeStamped {
    val createdAt: Date
    var updatedAt: Date
}

interface DateFormatting {
    fun string(date: Date): String
}

class DefaultDateFormatter : DateFormatting {
    private val formatter = SimpleDateFormat("dd.MM.yyyy HH:mm", Locale("ru"))
    override fun string(date: Date): String = formatter.format(date)
}

data class TextNoteModel(
    override val id: Int,
    var title: String,
    var text: String,
    override val createdAt: Date = Date(),
    override var updatedAt: Date = Date()
) : IdentifiableModel, TimeStamped

class TextNote(
    data: TextNoteModel,
    private val dateFormatter: DateFormatting = DefaultDateFormatter()
) : Note<TextNoteModel>(data) {

    override fun update(newData: TextNoteModel) {
        val updated = newData.copy(updatedAt = Date())
        super.update(updated)
    }

    override fun drawCanvas(): String {
        val created = dateFormatter.string(data.createdAt)
        val updated = dateFormatter.string(data.updatedAt)
        return """
            Текстовая заметка:
            ID: ${data.id}
            Заголовок: ${data.title}
            Текст: ${data.text}
            Создана: $created
            Обновлена: $updated
        """.trimIndent()
    }
}

data class ReminderNoteModel(
    override val id: Int,
    var text: String,
    var isDone: Boolean = false,
    override val createdAt: Date = Date(),
    override var updatedAt: Date = Date()
) : IdentifiableModel, TimeStamped

class ReminderNote(
    data: ReminderNoteModel,
    private val dateFormatter: DateFormatting = DefaultDateFormatter()
) : Note<ReminderNoteModel>(data) {

    override fun update(newData: ReminderNoteModel) {
        val updated = newData.copy(updatedAt = Date())
        super.update(updated)
    }

    override fun drawCanvas(): String {
        val status = if (data.isDone) "Выполнено" else "Не выполнено"
        val created = dateFormatter.string(data.createdAt)
        val updated = dateFormatter.string(data.updatedAt)
        return """
            Напоминание:
            ID: ${data.id}
            Текст: ${data.text}
            Статус: $status
            Создано: $created
            Обновлено: $updated
        """.trimIndent()
    }
}

class Notebook : CanvasUnit {
    private val notes = mutableListOf<AnyNote>()

    fun <T : IdentifiableModel> add(note: Note<T>) {
        notes.add(note)
    }

    fun removeAt(index: Int) {
        if (index in notes.indices) {
            notes[index].willRemove()
            notes.removeAt(index)
        }
    }

    fun removeNoteById(id: Int) {
        val iterator = notes.iterator()
        while (iterator.hasNext()) {
            val note = iterator.next()
            when (note) {
                is TextNote -> if (note.data.id == id) {
                    note.willRemove()
                    iterator.remove()
                }
                is ReminderNote -> if (note.data.id == id) {
                    note.willRemove()
                    iterator.remove()
                }
            }
        }
    }

    fun findTextNoteById(id: Int): TextNote? =
        notes.filterIsInstance<TextNote>().firstOrNull { it.data.id == id }

    fun findReminderNoteById(id: Int): ReminderNote? =
        notes.filterIsInstance<ReminderNote>().firstOrNull { it.data.id == id }

    override fun drawCanvas(): String =
        if (notes.isEmpty()) "Блокнот пуст"
        else notes.mapIndexed { index, note -> "${index + 1}. ${note.drawCanvas()}" }
            .joinToString("\n\n")
}

sealed class UserInput<out T> {
    data class Value<T>(val value: T) : UserInput<T>()
    object Canceled : UserInput<Nothing>()
}

class ConsoleUI {
    fun showMenuList(options: List<String>, message: String = "Выберите действие:"): Int {
        println("\n$message")
        options.forEachIndexed { index, option -> println("${index + 1}. $option") }
        while (true) {
            val input = readLine()
            val choice = input?.toIntOrNull()
            if (choice != null && choice in 1..options.size) return choice
            println("Неверный ввод. Попробуйте снова.")
        }
    }

    fun showCanvas(canvas: CanvasUnit) {
        println("\n===========================")
        println(canvas.drawCanvas())
        println("===========================\n")
    }

    fun readString(prompt: String = "Введите текст (или 'отмена' для выхода):"): UserInput<String> {
        print("$prompt ")
        val input = readLine()
        return when {
            input == null || input.lowercase() == "отмена" -> UserInput.Canceled
            input.isNotEmpty() -> UserInput.Value(input)
            else -> readString(prompt)
        }
    }

    fun readInt(prompt: String = "Введите число (или 'отмена' для выхода):"): UserInput<Int> {
        print("$prompt ")
        val input = readLine()
        return when {
            input == null || input.lowercase() == "отмена" -> UserInput.Canceled
            input.toIntOrNull() != null -> UserInput.Value(input.toInt())
            else -> readInt(prompt)
        }
    }
}

enum class MenuState {
    HOME, TEXT_NOTE_MENU, REMINDER_NOTE_MENU, NEW_TEXT_NOTE, NEW_REMINDER_NOTE
}

class Menu(
    private val ui: ConsoleUI,
    private val notebook: Notebook,
    private val dateFormatter: DateFormatting = DefaultDateFormatter()
) {
    private var state: MenuState = MenuState.HOME
    private var isRunning = true

    fun start() {
        while (isRunning) {
            when (state) {
                MenuState.HOME -> showHomeMenu()
                MenuState.TEXT_NOTE_MENU -> showTextNoteMenu()
                MenuState.REMINDER_NOTE_MENU -> showReminderNoteMenu()
                MenuState.NEW_TEXT_NOTE -> createTextNote()
                MenuState.NEW_REMINDER_NOTE -> createReminderNote()
            }
        }
    }

    private fun showHomeMenu() {
        when (ui.showMenuList(listOf(
            "Просмотреть все заметки",
            "Добавить заметку (выбрать тип)",
            "Редактировать заметку по ID",
            "Удалить заметку по ID",
            "Выход"
        ), "Главное меню:")) {
            1 -> ui.showCanvas(notebook)
            2 -> {
                when (ui.showMenuList(listOf("Текстовая заметка", "Напоминание", "Отмена"), "Выберите тип заметки:")) {
                    1 -> state = MenuState.NEW_TEXT_NOTE
                    2 -> state = MenuState.NEW_REMINDER_NOTE
                    else -> state = MenuState.HOME
                }
            }
            3 -> editNoteById()
            4 -> deleteNoteById()
            5 -> {
                println("Выход из приложения.")
                isRunning = false
            }
        }
    }

    private fun showTextNoteMenu() {
        when (ui.showMenuList(listOf(
            "Добавить текстовую заметку",
            "Редактировать заметку",
            "Удалить заметку",
            "Назад"
        ), "Меню текстовых заметок:")) {
            1 -> state = MenuState.NEW_TEXT_NOTE
            2 -> editNoteById()
            3 -> deleteNoteById()
            4 -> state = MenuState.HOME
        }
    }

    private fun showReminderNoteMenu() {
        when (ui.showMenuList(listOf(
            "Добавить напоминание",
            "Изменить статус напоминания",
            "Удалить напоминание",
            "Назад"
        ), "Меню напоминаний:")) {
            1 -> state = MenuState.NEW_REMINDER_NOTE
            2 -> toggleReminderStatus()
            3 -> deleteNoteById()
            4 -> state = MenuState.HOME
        }
    }

    private fun createTextNote() {
        val id = when (val input = ui.readInt("Введите ID (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Создание отменено."); state = MenuState.HOME; return }
        }
        val title = when (val input = ui.readString("Введите заголовок (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Создание отменено."); state = MenuState.HOME; return }
        }
        val text = when (val input = ui.readString("Введите текст заметки (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Создание отменено."); state = MenuState.HOME; return }
        }
        val now = Date()
        val model = TextNoteModel(id, title, text, now, now)
        val note = TextNote(model, dateFormatter)
        notebook.add(note)
        println("Текстовая заметка добавлена.")
        state = MenuState.HOME
    }

    private fun createReminderNote() {
        val id = when (val input = ui.readInt("Введите ID (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Создание отменено."); state = MenuState.HOME; return }
        }
        val text = when (val input = ui.readString("Введите текст напоминания (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Создание отменено."); state = MenuState.HOME; return }
        }
        val now = Date()
        val model = ReminderNoteModel(id, text, false, now, now)
        val note = ReminderNote(model, dateFormatter)
        notebook.add(note)
        println("Напоминание добавлено.")
        state = MenuState.HOME
    }

    private fun editNoteById() {
        ui.showCanvas(notebook)
        val id = when (val input = ui.readInt("Введите ID для редактирования (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Операция отменена."); state = MenuState.HOME; return }
        }
        notebook.findTextNoteById(id)?.let { note ->
            val newTitle = when (val input = ui.readString("Введите новый заголовок (или 'отмена'):")) {
                is UserInput.Value -> input.value
                UserInput.Canceled -> { println("Редактирование отменено."); state = MenuState.HOME; return }
            }
            val newText = when (val input = ui.readString("Введите новый текст (или 'отмена'):")) {
                is UserInput.Value -> input.value
                UserInput.Canceled -> { println("Редактирование отменено."); state = MenuState.HOME; return }
            }
            note.update(note.data.copy(title = newTitle, text = newText, updatedAt = Date()))
            println("Заметка обновлена.")
        } ?: notebook.findReminderNoteById(id)?.let { reminder ->
            val newText = when (val input = ui.readString("Введите новый текст напоминания (или 'отмена'):")) {
                is UserInput.Value -> input.value
                UserInput.Canceled -> { println("Редактирование отменено."); state = MenuState.HOME; return }
            }
            reminder.update(reminder.data.copy(text = newText, updatedAt = Date()))
            println("Напоминание обновлено.")
        } ?: println("Заметка с указанным ID не найдена.")
        state = MenuState.HOME
    }

    private fun toggleReminderStatus() {
        ui.showCanvas(notebook)
        val id = when (val input = ui.readInt("Введите ID напоминания (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Операция отменена."); state = MenuState.HOME; return }
        }
        notebook.findReminderNoteById(id)?.let { reminder ->
            val data = reminder.data.copy(isDone = !reminder.data.isDone, updatedAt = Date())
            reminder.update(data)
            println("Статус напоминания изменён.")
        } ?: println("Напоминание не найдено.")
        state = MenuState.HOME
    }

    private fun deleteNoteById() {
        ui.showCanvas(notebook)
        val id = when (val input = ui.readInt("Введите ID для удаления (или 'отмена'):")) {
            is UserInput.Value -> input.value
            UserInput.Canceled -> { println("Операция отменена."); state = MenuState.HOME; return }
        }
        notebook.removeNoteById(id)
        println("Если заметка с указанным ID существовала, она была удалена.")
        state = MenuState.HOME
    }
}

class NoteApp {
    fun run() {
        val ui = ConsoleUI()
        val notebook = Notebook()
        val menu = Menu(ui, notebook)
        menu.start()
    }
}

fun main() {
    val app = NoteApp()
    app.run()
}
