import Foundation

protocol IdentifiableModel {
    var id: Int { get }
}

final class Storage<T: IdentifiableModel> {
    private var storage: [T] = []
    
    init() {}
    init(_ item: T) { self.storage = [item] }
    
    func add(_ item: T) {
        removeById(item.id)
        storage.append(item)
    }
    
    func remove(_ item: T) {
        removeById(item.id)
    }
    
    func removeById(_ id: Int) {
        storage.removeAll { $0.id == id }
    }
    
    func getAll() -> [T] {
        return storage
    }
    
    func getValueById(id: Int) -> T? {
        return storage.first { $0.id == id }
    }
    
    func clear() {
        storage.removeAll()
    }
}

protocol CanvasUnit {
    func drawCanvas() -> String
}

protocol AnyNote: CanvasUnit {
    func willRemove()
}

class Note<Data: IdentifiableModel>: AnyNote {
    var storage: Storage<Data>
    var data: Data {
        didSet {
            storage.removeById(oldValue.id)
            storage.add(data)
        }
    }
    
    init(data: Data) {
        self.data = data
        self.storage = Storage(data)
    }
    
    func update(_ newData: Data) {
        self.data = newData
    }
    
    func willRemove() {
        storage.clear()
    }
    
    func drawCanvas() -> String {
        return "Заметка, id: \(data.id)"
    }
}

protocol TimeStamped {
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}

protocol DateFormatting {
    func string(from date: Date) -> String
}

final class DefaultDateFormatter: DateFormatting {
    private let formatter: DateFormatter
    init() {
        formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
    }
    func string(from date: Date) -> String {
        return formatter.string(from: date)
    }
}

struct TextNoteModel: IdentifiableModel, TimeStamped {
    let id: Int
    var title: String
    var text: String
    let createdAt: Date
    var updatedAt: Date
    init(id: Int, title: String, text: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

class TextNote: Note<TextNoteModel> {
    private let dateFormatter: DateFormatting
    init(data: TextNoteModel, dateFormatter: DateFormatting = DefaultDateFormatter()) {
        self.dateFormatter = dateFormatter
        super.init(data: data)
    }
    
    override func update(_ newData: TextNoteModel) {
        var updated = newData
        updated.updatedAt = Date()
        super.update(updated)
    }
    
    override func drawCanvas() -> String {
        let created = dateFormatter.string(from: data.createdAt)
        let updated = dateFormatter.string(from: data.updatedAt)
        return """
        Текстовая заметка:
        ID: \(data.id)
        Заголовок: \(data.title)
        Текст: \(data.text)
        Создана: \(created)
        Обновлена: \(updated)
        """
    }
}

struct ReminderNoteModel: IdentifiableModel, TimeStamped {
    let id: Int
    var text: String
    var isDone: Bool
    let createdAt: Date
    var updatedAt: Date
    init(id: Int, text: String, isDone: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

class ReminderNote: Note<ReminderNoteModel> {
    private let dateFormatter: DateFormatting
    init(data: ReminderNoteModel, dateFormatter: DateFormatting = DefaultDateFormatter()) {
        self.dateFormatter = dateFormatter
        super.init(data: data)
    }
    
    override func update(_ newData: ReminderNoteModel) {
        var updated = newData
        updated.updatedAt = Date()
        super.update(updated)
    }
    
    override func drawCanvas() -> String {
        let status = data.isDone ? "Выполнено" : "Не выполнено"
        let created = dateFormatter.string(from: data.createdAt)
        let updated = dateFormatter.string(from: data.updatedAt)
        return """
        Напоминание:
        ID: \(data.id)
        Текст: \(data.text)
        Статус: \(status)
        Создано: \(created)
        Обновлено: \(updated)
        """
    }
}

class Notebook: CanvasUnit {
    fileprivate var notes: [AnyNote] = []
    
    func add<T: IdentifiableModel>(_ note: Note<T>) {
        notes.append(note)
    }
    
    func remove(at index: Int) {
        guard index >= 0 && index < notes.count else { return }
        notes[index].willRemove()
        notes.remove(at: index)
    }
    
    func removeNoteById(id: Int) {
        notes.removeAll { element in
            if let textNote = element as? TextNote, textNote.data.id == id {
                textNote.willRemove()
                return true
            }
            if let remNote = element as? ReminderNote, remNote.data.id == id {
                remNote.willRemove()
                return true
            }
            return false
        }
    }
    
    func findTextNoteById(id: Int) -> TextNote? {
        return notes.compactMap { $0 as? TextNote }.first { $0.data.id == id }
    }
    
    func findReminderNoteById(id: Int) -> ReminderNote? {
        return notes.compactMap { $0 as? ReminderNote }.first { $0.data.id == id }
    }
    
    func drawCanvas() -> String {
        if notes.isEmpty {
            return "Блокнот пуст"
        }
        return notes.enumerated().map { "\($0.offset + 1). \($0.element.drawCanvas())" }.joined(separator: "\n\n")
    }
    
    func aggregateAllItems<T: IdentifiableModel>(ofType type: T.Type) -> [T] {
        var all: [T] = []
        for element in notes {
            if let note = element as? Note<T> {
                all.append(contentsOf: note.storage.getAll())
            }
        }
        return all
    }
}

enum UserInput<T> {
    case value(T)
    case canceled
}

class ConsoleUI {
    func showMenuList(options: [String], message: String = "Выберите действие:") -> Int {
        print("\n\(message)")
        for (index, option) in options.enumerated() {
            print("\(index + 1). \(option)")
        }
        while true {
            if let input = readLine(), let choice = Int(input), choice > 0, choice <= options.count {
                return choice
            } else {
                print("Неверный ввод. Попробуйте снова.")
            }
        }
    }
    
    func showCanvas(_ canvas: CanvasUnit) {
        print("\n===========================")
        print(canvas.drawCanvas())
        print("===========================\n")
    }
    
    func readString(prompt: String = "Введите текст (или 'отмена' для выхода):") -> UserInput<String> {
        print(prompt, terminator: " ")
        if let input = readLine() {
            if input.lowercased() == "отмена" {
                return .canceled
            } else if !input.isEmpty {
                return .value(input)
            }
        }
        print("Неверный ввод. Попробуйте снова или введите 'отмена'.")
        return readString(prompt: prompt)
    }
    
    func readInt(prompt: String = "Введите число (или 'отмена' для выхода):") -> UserInput<Int> {
        print(prompt, terminator: " ")
        if let input = readLine() {
            if input.lowercased() == "отмена" {
                return .canceled
            } else if let number = Int(input) {
                return .value(number)
            }
        }
        print("Неверный ввод. Попробуйте снова или введите 'отмена'.")
        return readInt(prompt: prompt)
    }
}

enum MenuState {
    case home
    case textNoteMenu
    case reminderNoteMenu
    case newTextNote
    case newReminderNote
}

class Menu {
    private let ui: ConsoleUI
    private let notebook: Notebook
    private var state: MenuState = .home
    private var isRunning = true
    private let dateFormatter: DateFormatting
    
    init(ui: ConsoleUI, notebook: Notebook, dateFormatter: DateFormatting = DefaultDateFormatter()) {
        self.ui = ui
        self.notebook = notebook
        self.dateFormatter = dateFormatter
    }
    
    func start() {
        while isRunning {
            switch state {
            case .home:
                showHomeMenu()
            case .textNoteMenu:
                showTextNoteMenu()
            case .reminderNoteMenu:
                showReminderNoteMenu()
            case .newTextNote:
                createTextNote()
            case .newReminderNote:
                createReminderNote()
            }
        }
    }
    
    private func showHomeMenu() {
        let choice = ui.showMenuList(options: [
            "Просмотреть все заметки",
            "Добавить заметку (выбрать тип)",
            "Редактировать заметку по ID",
            "Удалить заметку по ID",
            "Выход"
        ], message: "Главное меню:")
        
        switch choice {
        case 1:
            ui.showCanvas(notebook)
        case 2:
            let typeChoice = ui.showMenuList(options: ["Текстовая заметка", "Напоминание", "Отмена"], message: "Выберите тип заметки:")
            switch typeChoice {
            case 1: state = .newTextNote
            case 2: state = .newReminderNote
            default: state = .home
            }
        case 3:
            editNoteById()
        case 4:
            deleteNoteById()
        case 5:
            print("Выход из приложения.")
            isRunning = false
        default:
            break
        }
    }
    
    private func showTextNoteMenu() {
        let choice = ui.showMenuList(options: [
            "Добавить текстовую заметку",
            "Редактировать заметку",
            "Удалить заметку",
            "Назад"
        ], message: "Меню текстовых заметок:")
        
        switch choice {
        case 1: state = .newTextNote
        case 2: editNoteById()
        case 3: deleteNoteById()
        case 4: state = .home
        default: break
        }
    }
    
    private func showReminderNoteMenu() {
        let choice = ui.showMenuList(options: [
            "Добавить напоминание",
            "Изменить статус напоминания",
            "Удалить напоминание",
            "Назад"
        ], message: "Меню напоминаний:")
        
        switch choice {
        case 1: state = .newReminderNote
        case 2: toggleReminderStatus()
        case 3: deleteNoteById()
        case 4: state = .home
        default: break
        }
    }
    
    private func createTextNote() {
        guard case let .value(id) = ui.readInt(prompt: "Введите ID (или 'отмена'):" ) else {
            print("Создание отменено.")
            state = .home
            return
        }
        guard case let .value(title) = ui.readString(prompt: "Введите заголовок (или 'отмена'):" ) else {
            print("Создание отменено.")
            state = .home
            return
        }
        guard case let .value(text) = ui.readString(prompt: "Введите текст заметки (или 'отмена'):" ) else {
            print("Создание отменено.")
            state = .home
            return
        }
        let now = Date()
        let model = TextNoteModel(id: id, title: title, text: text, createdAt: now, updatedAt: now)
        let note = TextNote(data: model, dateFormatter: dateFormatter)
        notebook.add(note)
        print("Текстовая заметка добавлена.")
        state = .home
    }
    
    private func createReminderNote() {
        guard case let .value(id) = ui.readInt(prompt: "Введите ID (или 'отмена'):" ) else {
            print("Создание отменено.")
            state = .home
            return
        }
        guard case let .value(text) = ui.readString(prompt: "Введите текст напоминания (или 'отмена'):" ) else {
            print("Создание отменено.")
            state = .home
            return
        }
        let now = Date()
        let model = ReminderNoteModel(id: id, text: text, isDone: false, createdAt: now, updatedAt: now)
        let note = ReminderNote(data: model, dateFormatter: dateFormatter)
        notebook.add(note)
        print("Напоминание добавлено.")
        state = .home
    }
    
    private func editNoteById() {
        ui.showCanvas(notebook)
        guard case let .value(id) = ui.readInt(prompt: "Введите ID для редактирования (или 'отмена'):" ) else {
            print("Операция отменена.")
            state = .home
            return
        }
        if let note = notebook.findTextNoteById(id: id) {
            guard case let .value(newTitle) = ui.readString(prompt: "Введите новый заголовок (или 'отмена'):" ) else {
                print("Редактирование отменено.")
                state = .home
                return
            }
            guard case let .value(newText) = ui.readString(prompt: "Введите новый текст (или 'отмена'):" ) else {
                print("Редактирование отменено.")
                state = .home
                return
            }
            var updated = note.data
            updated.title = newTitle
            updated.text = newText
            updated.updatedAt = Date()
            note.update(updated)
            print("Заметка обновлена.")
        } else if let reminder = notebook.findReminderNoteById(id: id) {
            guard case let .value(newText) = ui.readString(prompt: "Введите новый текст напоминания (или 'отмена'):" ) else {
                print("Редактирование отменено.")
                state = .home
                return
            }
            var updated = reminder.data
            updated.text = newText
            updated.updatedAt = Date()
            reminder.update(updated)
            print("Напоминание обновлено.")
        } else {
            print("Заметка с указанным ID не найдена.")
        }
        state = .home
    }
    
    private func toggleReminderStatus() {
        ui.showCanvas(notebook)
        guard case let .value(id) = ui.readInt(prompt: "Введите ID напоминания (или 'отмена'):" ) else {
            print("Операция отменена.")
            state = .home
            return
        }
        if let reminder = notebook.findReminderNoteById(id: id) {
            var data = reminder.data
            data.isDone.toggle()
            data.updatedAt = Date()
            reminder.update(data)
            print("Статус напоминания изменён.")
        } else {
            print("Напоминание не найдено.")
        }
        state = .home
    }
    
    private func deleteNoteById() {
        ui.showCanvas(notebook)
        guard case let .value(id) = ui.readInt(prompt: "Введите ID для удаления (или 'отмена'):" ) else {
            print("Операция отменена.")
            state = .home
            return
        }
        notebook.removeNoteById(id: id)
        print("Если заметка с указанным ID существовала, она была удалена.")
        state = .home
    }
}

class NoteApp {
    func run() {
        let ui = ConsoleUI()
        let notebook = Notebook()
        let menu = Menu(ui: ui, notebook: notebook)
        menu.start()
    }
}

let app = NoteApp()
app.run()
