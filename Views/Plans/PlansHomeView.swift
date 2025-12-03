import SwiftUI

private enum PlansColors {
    static let backgroundTop = Color(hex: "#050B1F")
    static let backgroundBottom = Color(hex: "#0F1431")
    static let cardTop = Color(hex: "#1F2446")
    static let cardBottom = Color(hex: "#121530")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let accent = Color(hex: "#7C83FF")
    static let success = Color(hex: "#20C997")
    static let border = Color.white.opacity(0.12)
}

struct PlansHomeView: View {
    @StateObject private var viewModel: PlansViewModel
    @State private var editorMode: PlanEditorMode?

    init(container: AppContainer? = nil) {
        let resolvedContainer = container ?? AppContainer(mockMode: true)
        _viewModel = StateObject(
            wrappedValue: PlansViewModel(
                repository: resolvedContainer.plansRepository,
                scheduler: resolvedContainer.planScheduler,
                assetRepository: resolvedContainer.assetRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [PlansColors.backgroundTop, PlansColors.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        calendarSection
                        remindersSection
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editorMode = .create(
                            viewModel.makeDefaultInput(for: viewModel.selectedDate))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay(loadingOverlay)
        }
        .sheet(item: $editorMode) { mode in
            PlanEditorSheet(
                mode: mode,
                assets: viewModel.assetOptions,
                onSave: { input in
                    switch mode {
                    case .create:
                        viewModel.createPlan(input: input)
                    case .edit(let plan, _):
                        viewModel.update(plan: plan, with: input)
                    }
                },
                onDelete: {
                    if case .edit(let plan, _) = mode {
                        viewModel.delete(plan: plan)
                    }
                }
            )
        }
        .onAppear {
            viewModel.load()
        }
    }
}

extension PlansHomeView {
    fileprivate var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("plans_loading")
                    .padding(24)
                    .background(
                        LinearGradient(
                            colors: [PlansColors.cardTop, PlansColors.cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PlansColors.border, lineWidth: 1)
                    )
            } else {
                EmptyView()
            }
        }
    }

    fileprivate var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar")
                .font(.title2.bold())
                .foregroundColor(PlansColors.textPrimary)
            HStack {
                summaryCard(
                    title: NSLocalizedString("Active Plans", comment: ""),
                    value: "\(viewModel.activePlanCount)")
                summaryCard(
                    title: NSLocalizedString("Next", comment: ""),
                    value: viewModel.nextReminderText)
            }
        }
    }

    fileprivate func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(PlansColors.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundColor(PlansColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [PlansColors.cardTop, PlansColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PlansColors.border, lineWidth: 1)
        )
    }

    fileprivate var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: viewModel.goToPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(PlansColors.textPrimary)
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                    .foregroundColor(PlansColors.textPrimary)
                Spacer()
                Button(action: viewModel.goToNextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(PlansColors.textPrimary)
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8
            ) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundColor(PlansColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(viewModel.calendarDays) { day in
                    Button {
                        viewModel.select(day)
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(
                                    .subheadline.weight(
                                        day.isWithinDisplayedMonth ? .semibold : .regular)
                                )
                                .foregroundColor(dayTextColor(day))
                                .frame(maxWidth: .infinity)
                            Circle()
                                .fill(day.hasReminder ? PlansColors.accent : Color.clear)
                                .frame(width: 6, height: 6)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    viewModel.selectedDate == day.date
                                        ? PlansColors.accent.opacity(0.18) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onTapGesture(count: 2) {
                        if let plan = viewModel.plans(on: day.date).first {
                            editorMode = .edit(plan, viewModel.makeInput(from: plan))
                        }
                    }
                    .contextMenu {
                        let dayPlans = viewModel.plans(on: day.date)
                        if dayPlans.isEmpty {
                            Text("No plan for today")
                        } else {
                            ForEach(dayPlans) { plan in
                                Button(
                                    "\(plan.title) - \(NSLocalizedString("common_edit", comment: ""))"
                                ) {
                                    editorMode = .edit(plan, viewModel.makeInput(from: plan))
                                }
                                Button(role: .destructive) {
                                    viewModel.delete(plan: plan)
                                } label: {
                                    Text(
                                        "\(plan.title) - \(NSLocalizedString("common_delete", comment: ""))"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [PlansColors.cardTop, PlansColors.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PlansColors.border, lineWidth: 1)
            )
            selectedDateInfo
        }
    }

    private var selectedDateInfo: some View {
        let plansForDay = viewModel.plans(on: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PlansColors.textPrimary)
                Spacer()
                if plansForDay.isEmpty {
                    Button("Create Plan") {
                        editorMode = .create(
                            viewModel.makeDefaultInput(for: viewModel.selectedDate))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlansColors.accent)
                }
            }
            if plansForDay.isEmpty {
                Text("No plan for today")
                    .font(.footnote)
                    .foregroundColor(PlansColors.textSecondary)
            } else {
                ForEach(plansForDay) { plan in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(plan.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(PlansColors.textPrimary)
                            Text(plan.assetCode.rawValue)
                                .font(.caption)
                                .foregroundColor(PlansColors.textSecondary)
                        }
                        Spacer()
                        Button("common_edit") {
                            editorMode = .edit(plan, viewModel.makeInput(from: plan))
                        }
                        .buttonStyle(.bordered)
                        .tint(PlansColors.accent)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PlansColors.cardTop, PlansColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PlansColors.border, lineWidth: 1)
        )
    }

    fileprivate var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                    .foregroundColor(PlansColors.textPrimary)
                Spacer()
                Text(viewModel.selectedDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(PlansColors.textSecondary)
            }
            if viewModel.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 28))
                        .foregroundColor(PlansColors.textSecondary)
                    Text("No reminders today")
                        .font(.subheadline)
                        .foregroundColor(PlansColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [PlansColors.cardTop, PlansColors.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PlansColors.border, lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.reminders) { reminder in
                        reminderRow(reminder)
                            .contextMenu {
                                Button("plans_edit_plan") {
                                    editorMode = .edit(
                                        reminder.plan, viewModel.makeInput(from: reminder.plan))
                                }
                                Button(role: .destructive) {
                                    viewModel.delete(plan: reminder.plan)
                                } label: {
                                    Text("plans_delete_plan")
                                }
                            }
                    }
                }
            }
        }
    }

    fileprivate func reminderRow(_ reminder: PlansViewModel.ReminderItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.plan.title)
                        .font(.headline)
                        .foregroundColor(PlansColors.textPrimary)
                    Text(
                        "\(reminder.plan.assetCode.displayName) • \(reminder.plan.amountValue.formatted(.number)) \(reminder.plan.amountUnit)"
                    )
                    .font(.caption)
                    .foregroundColor(PlansColors.textSecondary)
                }
                Spacer()
                Text(reminder.state.labelText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(reminder.state.color.opacity(0.15))
                    .foregroundColor(reminder.state.color)
                    .clipShape(Capsule())
            }
            HStack {
                Label(
                    reminder.fireDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundColor(PlansColors.textSecondary)
                Spacer()
                Button("plans_completed") {
                    viewModel.complete(reminder)
                }
                .buttonStyle(.borderedProminent)
                .tint(PlansColors.success)
                Button("plans_snooze") {
                    viewModel.skip(reminder)
                }
                .buttonStyle(.bordered)
                .tint(PlansColors.accent)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [PlansColors.cardTop, PlansColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PlansColors.border, lineWidth: 1)
        )
    }

    fileprivate var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Completed")
                .font(.headline)
                .foregroundColor(PlansColors.textPrimary)
            if viewModel.history.isEmpty {
                Text("No completed plans yet")
                    .font(.subheadline)
                    .foregroundColor(PlansColors.textSecondary)
            } else {
                ForEach(viewModel.history) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(PlansColors.textPrimary)
                            Text(item.date, style: .date)
                                .font(.caption)
                                .foregroundColor(PlansColors.textSecondary)
                        }
                        Spacer()
                        if let note = item.note {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(PlansColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PlansColors.cardTop, PlansColors.cardBottom], startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PlansColors.border, lineWidth: 1)
        )
    }

    fileprivate var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    fileprivate var weekdaySymbols: [String] {
        DateFormatter.turkishShortWeekdaySymbols
    }

    fileprivate var monthTitle: String {
        DateFormatter.turkishMonthFormatter.string(from: viewModel.month)
    }

    fileprivate func dayTextColor(_ day: PlansViewModel.CalendarDay) -> Color {
        if day.isWithinDisplayedMonth {
            return day.isToday ? PlansColors.accent : PlansColors.textPrimary
        }
        return PlansColors.textSecondary
    }
}

// MARK: - Plan Editor Sheet
private enum PlanEditorMode: Identifiable {
    case create(PlansViewModel.PlanCreationInput)
    case edit(PlanRecord, PlansViewModel.PlanCreationInput)
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let plan, _): return plan.id.uuidString
        }
    }
    var title: String {
        switch self {
        case .create: return NSLocalizedString("Create Plan", comment: "")
        case .edit: return NSLocalizedString("plans_edit_plan", comment: "")
        }
    }
    var initialInput: PlansViewModel.PlanCreationInput {
        switch self {
        case .create(let input): return input
        case .edit(_, let input): return input
        }
    }
    var plan: PlanRecord? {
        if case .edit(let plan, _) = self { return plan }
        return nil
    }
}

private struct PlanEditorSheet: View {
    let mode: PlanEditorMode
    let assets: [AssetDefinition]
    let onSave: (PlansViewModel.PlanCreationInput) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    @State private var selectedAssetCode: String
    @State private var showingAssetPicker = false
    @State private var amountText: String
    @State private var amountUnit: String
    @State private var frequency: DCAFrequency
    @State private var dayOfMonth: Int
    @State private var weekday: Int
    @State private var includeMinusThree: Bool
    @State private var includeMinusOne: Bool
    @State private var extraOffsets: [Int]
    @State private var errorMessage: String?

    init(
        mode: PlanEditorMode, assets: [AssetDefinition],
        onSave: @escaping (PlansViewModel.PlanCreationInput) -> Void, onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.assets = assets
        self.onSave = onSave
        self.onDelete = onDelete
        let input = mode.initialInput
        _titleText = State(initialValue: input.title)
        _selectedAssetCode = State(initialValue: input.assetCode.uppercased())
        _amountText = State(initialValue: NSDecimalNumber(decimal: input.amount).stringValue)
        _amountUnit = State(initialValue: input.unit)
        _frequency = State(initialValue: input.frequency)
        _dayOfMonth = State(initialValue: max(1, input.scheduleDay))
        _weekday = State(initialValue: max(1, input.scheduleDay))
        let offsets = Set(input.reminderOffsets)
        _includeMinusThree = State(initialValue: offsets.contains(-3))
        _includeMinusOne = State(initialValue: offsets.contains(-1))
        _extraOffsets = State(initialValue: input.reminderOffsets.filter { $0 != -3 && $0 != -1 })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [PlansColors.backgroundTop, PlansColors.backgroundBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        sectionCard(title: NSLocalizedString("Plan Details", comment: "")) {
                            labeledField(NSLocalizedString("Plan Name", comment: "")) {
                                TextField("Plan Name", text: $titleText)
                                    .padding(12)
                                    .background(fieldBackground)
                                    .overlay(fieldOverlay)
                                    .foregroundColor(PlansColors.textPrimary)
                            }

                            Button {
                                showingAssetPicker = true
                            } label: {
                                HStack {
                                    Text("Asset")
                                        .foregroundColor(PlansColors.textSecondary)
                                    Spacer()
                                    Text(selectedAssetDisplayName)
                                        .foregroundColor(PlansColors.textPrimary)
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(PlansColors.textSecondary)
                                }
                                .padding(12)
                                .background(fieldBackground)
                                .overlay(fieldOverlay)
                            }
                            .disabled(assets.isEmpty)

                            labeledField(NSLocalizedString("Amount", comment: "")) {
                                TextField("0,00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(fieldBackground)
                                    .overlay(fieldOverlay)
                                    .foregroundColor(PlansColors.textPrimary)
                            }

                            Picker("Unit", selection: $amountUnit) {
                                Text("Gram").tag("gram")
                                Text("Piece").tag("adet")
                                Text("Currency").tag("TRY")
                            }

                            .pickerStyle(.segmented)
                            .colorMultiply(PlansColors.accent)
                        }

                        sectionCard(title: NSLocalizedString("Schedule", comment: "")) {
                            Picker("Frequency", selection: $frequency) {
                                ForEach(DCAFrequency.allCases, id: \.self) { freq in
                                    Text(freq.displayName).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorMultiply(PlansColors.accent)

                            if frequency == .monthly {
                                Stepper(value: $dayOfMonth, in: 1...28) {
                                    Text(
                                        String(
                                            format: NSLocalizedString(
                                                "plans_day_of_month", comment: ""), dayOfMonth)
                                    )
                                    .foregroundColor(PlansColors.textPrimary)
                                }
                            } else {
                                Picker("Day", selection: $weekday) {
                                    ForEach(1...7, id: \.self) { day in
                                        Text(weekdayName(day)).tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(PlansColors.textPrimary)
                            }
                        }

                        sectionCard(
                            title: NSLocalizedString("Reminders", comment: "")
                        ) {
                            Toggle("3 Days Before", isOn: $includeMinusThree)
                                .toggleStyle(SwitchToggleStyle(tint: PlansColors.accent))
                                .foregroundColor(PlansColors.textPrimary)
                            Toggle("1 Day Before", isOn: $includeMinusOne)
                                .toggleStyle(SwitchToggleStyle(tint: PlansColors.accent))
                                .foregroundColor(PlansColors.textPrimary)
                            if !extraOffsets.isEmpty {
                                Text(
                                    "\(NSLocalizedString("plans_extra_reminders", comment: "")): \(extraOffsets.map(String.init).joined(separator: ", "))"
                                )
                                .font(.footnote)
                                .foregroundColor(PlansColors.textSecondary)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: handleSave) {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            PlansColors.accent, PlansColors.accent.opacity(0.7),
                                        ], startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PlansColors.border, lineWidth: 1)
                                )
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.6)

                        if case .edit = mode, let onDelete {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                Text("plans_delete_plan")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAssetPicker) {
            PlanAssetPickerSheet(
                isPresented: $showingAssetPicker,
                selectedCode: $selectedAssetCode,
                assets: assets
            )
        }
        .onAppear {
            if selectedAssetCode.isEmpty {
                selectedAssetCode = assets.first?.code.uppercased() ?? selectedAssetCode
            }
        }
    }

    private var fieldBackground: some View {
        LinearGradient(
            colors: [PlansColors.cardTop.opacity(0.9), PlansColors.cardBottom],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var fieldOverlay: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(PlansColors.border, lineWidth: 1)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(PlansColors.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PlansColors.cardTop, PlansColors.cardBottom], startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PlansColors.border, lineWidth: 1)
        )
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(PlansColors.textSecondary)
            content()
        }
    }

    private func weekdayName(_ value: Int) -> String {
        let symbols = Locale(identifier: "en_US").localizedWeekdaySymbols
        let index = (value - 1 + symbols.count) % symbols.count
        return symbols[index].capitalized
    }

    private func handleSave() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
        else {
            errorMessage = NSLocalizedString("Enter a valid amount", comment: "")
            return
        }
        var offsets = extraOffsets
        if includeMinusThree { offsets.append(-3) }
        if includeMinusOne { offsets.append(-1) }
        if offsets.isEmpty { offsets.append(-1) }
        let scheduleDayValue = frequency == .monthly ? dayOfMonth : weekday
        let input = PlansViewModel.PlanCreationInput(
            title: titleText,
            assetCode: selectedAssetCode.uppercased(),
            amount: amount,
            unit: amountUnit,
            frequency: frequency,
            scheduleDay: scheduleDayValue,
            reminderOffsets: Array(Set(offsets)).sorted()
        )
        onSave(input)
        dismiss()
    }

    private var selectedAssetDisplayName: String {
        assets.first(where: { $0.code.caseInsensitiveCompare(selectedAssetCode) == .orderedSame })?
            .displayName ?? selectedAssetCode
    }

    private var canSave: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedAssetCode.isEmpty
    }
}

private struct PlanAssetPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedCode: String
    let assets: [AssetDefinition]
    @State private var searchText: String = ""
    @State private var selectedCategory: AssetType? = nil

    private var categories: [AssetType?] {
        let detected = Array(
            Set(assets.compactMap { AssetType(rawValue: $0.category.lowercased()) })
        )
        .sorted { $0.displayName < $1.displayName }
        return [nil] + detected
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [PlansColors.backgroundTop, PlansColors.backgroundBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    TextField("Varlık ara", text: $searchText)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [PlansColors.cardTop, PlansColors.cardBottom],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PlansColors.border, lineWidth: 1)
                        )
                        .foregroundColor(PlansColors.textPrimary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                                let isSelected = selectedCategory?.rawValue == category?.rawValue
                                Button {
                                    withAnimation { selectedCategory = category }
                                } label: {
                                    Text(categoryTitle(category))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(
                                            isSelected ? .white : PlansColors.textSecondary
                                        )
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule().fill(
                                                isSelected
                                                    ? PlansColors.accent
                                                    : PlansColors.cardTop.opacity(0.8))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if assets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(PlansColors.textSecondary)
                            Text("Aktif varlık bulunamadı")
                                .font(.subheadline)
                                .foregroundColor(PlansColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(
                                groupedAssets.keys.sorted(by: { $0.displayName < $1.displayName }),
                                id: \.self
                            ) { category in
                                if let assets = groupedAssets[category] {
                                    Section(category.displayName) {
                                        ForEach(assets, id: \.objectID) { asset in
                                            Button {
                                                selectedCode = asset.code.uppercased()
                                                isPresented = false
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading) {
                                                        Text(asset.displayName)
                                                            .foregroundColor(
                                                                PlansColors.textPrimary)
                                                        Text(asset.code)
                                                            .font(.caption)
                                                            .foregroundColor(
                                                                PlansColors.textSecondary)
                                                    }
                                                    Spacer()
                                                    if asset.code.caseInsensitiveCompare(
                                                        selectedCode) == .orderedSame
                                                    {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(PlansColors.accent)
                                                    }
                                                }
                                            }
                                            .listRowBackground(
                                                LinearGradient(
                                                    colors: [
                                                        PlansColors.cardTop, PlansColors.cardBottom,
                                                    ], startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Asset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { isPresented = false }
                }
            }
        }
    }

    private var filteredAssets: [AssetDefinition] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return assets.filter { asset in
            let matchesCategory =
                selectedCategory.map { asset.category.lowercased() == $0.rawValue } ?? true
            let displayName = asset.displayName.lowercased()
            let code = asset.code.lowercased()
            let matchesSearch = query.isEmpty || displayName.contains(query) || code.contains(query)
            return matchesCategory && matchesSearch
        }
    }

    private var groupedAssets: [AssetType: [AssetDefinition]] {
        Dictionary(
            grouping: filteredAssets,
            by: { AssetType(rawValue: $0.category.lowercased()) ?? .crypto })
    }

    private func categoryTitle(_ category: AssetType?) -> String {
        guard let category else { return "Tümü" }
        return category.displayName
    }
}

extension Locale {
    fileprivate var localizedWeekdaySymbols: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = self
        return calendar.weekdaySymbols
    }
}
