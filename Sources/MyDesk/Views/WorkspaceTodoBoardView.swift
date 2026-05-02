import MyDeskCore
import SwiftData
import SwiftUI

struct WorkspaceTodoBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoColumnRatio) private var columnRatio = TodoBoardColumnSplit.defaultRatio

    let workspaceId: String
    let todos: [WorkspaceTodoModel]
    @Binding var isOpen: Bool
    @Binding var isDoneColumnOpen: Bool
    let onStatus: (String) -> Void

    @State private var draftTitle = ""
    @State private var dragStartRatio: Double?

    private var openTodos: [WorkspaceTodoModel] {
        todos
            .filter { !$0.isCompleted }
            .sorted {
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    private var completedTodos: [WorkspaceTodoModel] {
        todos
            .filter(\.isCompleted)
            .sorted {
                let lhs = $0.completedAt ?? $0.updatedAt
                let rhs = $1.completedAt ?? $1.updatedAt
                if lhs != rhs { return lhs > rhs }
                return $0.title < $1.title
            }
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            if isOpen {
                boardBody
            }
        }
        .padding(isOpen ? 10 : 8)
        .frame(maxWidth: .infinity)
        .frame(height: isOpen ? 244 : 42)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("待办", systemImage: "checklist")
                .font(.headline)
            Text("\(openTodos.count) 待办 · \(completedTodos.count) 已完成")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                isDoneColumnOpen.toggle()
            } label: {
                Label(isDoneColumnOpen ? "隐藏已完成" : "显示已完成", systemImage: isDoneColumnOpen ? "sidebar.right" : "sidebar.leading")
            }
            .disabled(!isOpen)

            Button {
                isOpen.toggle()
            } label: {
                Label(isOpen ? "关闭待办" : "打开待办", systemImage: isOpen ? "chevron.down" : "chevron.up")
            }
        }
        .buttonStyle(.bordered)
    }

    private var boardBody: some View {
        GeometryReader { proxy in
            if isDoneColumnOpen {
                let dividerWidth = 10.0
                let availableWidth = max(proxy.size.width - dividerWidth, 1)
                let ratio = TodoBoardColumnSplit.clampedRatio(columnRatio)
                let todoWidth = availableWidth * ratio

                HStack(spacing: 0) {
                    todoColumn(
                        title: "待办",
                        systemImage: "circle",
                        items: openTodos,
                        emptyText: "暂无待办"
                    )
                    .frame(width: todoWidth)

                    splitDivider(availableWidth: availableWidth)
                        .frame(width: dividerWidth)

                    todoColumn(
                        title: "已完成",
                        systemImage: "checkmark.circle",
                        items: completedTodos,
                        emptyText: "暂无已完成事项"
                    )
                    .frame(width: availableWidth - todoWidth)
                }
            } else {
                todoColumn(
                    title: "待办",
                    systemImage: "circle",
                    items: openTodos,
                    emptyText: "暂无待办"
                )
            }
        }
    }

    private func todoColumn(title: String, systemImage: String, items: [WorkspaceTodoModel], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if title == "待办" {
                    addTodoField
                }
            }

            if items.isEmpty {
                ContentUnavailableView(emptyText, systemImage: systemImage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { todo in
                            todoRow(todo)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var addTodoField: some View {
        HStack(spacing: 6) {
            TextField("新增待办", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit(addTodo)

            Button(action: addTodo) {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("新增待办")
        }
    }

    private func todoRow(_ todo: WorkspaceTodoModel) -> some View {
        HStack(spacing: 8) {
            Button {
                toggle(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            TextField("待办事项", text: Binding(
                get: { todo.title },
                set: { newValue in
                    todo.title = newValue
                    todo.updatedAt = .now
                    try? modelContext.save()
                }
            ))
            .textFieldStyle(.plain)
            .strikethrough(todo.isCompleted)
            .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Button(role: .destructive) {
                delete(todo)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("删除")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func splitDivider(availableWidth: Double) -> some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = TodoBoardColumnSplit.clampedRatio(columnRatio)
                        }
                        let start = dragStartRatio ?? TodoBoardColumnSplit.defaultRatio
                        columnRatio = TodoBoardColumnSplit.clampedRatio(start + Double(value.translation.width) / availableWidth)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
            .help("拖动调整待办和已完成的宽度")
    }

    private func addTodo() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let todo = WorkspaceTodoModel(
            workspaceId: workspaceId,
            title: title,
            sortIndex: nextSortIndex(isCompleted: false)
        )
        modelContext.insert(todo)
        draftTitle = ""
        save(status: "Added todo")
    }

    private func toggle(_ todo: WorkspaceTodoModel) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? .now : nil
        todo.sortIndex = nextSortIndex(isCompleted: todo.isCompleted)
        todo.updatedAt = .now
        save(status: todo.isCompleted ? "Marked todo complete" : "Moved todo back")
    }

    private func delete(_ todo: WorkspaceTodoModel) {
        modelContext.delete(todo)
        save(status: "Deleted todo")
    }

    private func nextSortIndex(isCompleted: Bool) -> Int {
        let matching = todos.filter { $0.isCompleted == isCompleted }
        return (matching.map(\.sortIndex).max() ?? -1) + 1
    }

    private func save(status: String) {
        do {
            try modelContext.save()
            onStatus(status)
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }
}
