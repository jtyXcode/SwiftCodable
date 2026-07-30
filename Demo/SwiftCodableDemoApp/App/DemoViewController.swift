import SwiftCodable
import UIKit

/// Demo 首页：使用 UITableView 展示全部示例，点击后进入独立解析页。
final class DemoViewController: UITableViewController {
    private let sections = DemoSection.allCases

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SwiftCodable"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.accessibilityIdentifier = "scenarioTable"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 74
        tableView.tableHeaderView = makeHeader()
        configureDiagnosticsMenu()
    }

    override func numberOfSections(
        in tableView: UITableView
    ) -> Int {
        sections.count
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        DemoScenario.scenarios(in: sections[section]).count
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        sections[section].rawValue
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let scenario = scenario(at: indexPath)
        let cell = UITableViewCell(
            style: .subtitle,
            reuseIdentifier: nil
        )

        var content = cell.defaultContentConfiguration()
        content.text = scenario.title
        content.secondaryText = scenario.detail
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: scenario.symbolName)
        content.imageProperties.tintColor = .systemIndigo
        content.imageToTextPadding = 12
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = scenario.title
        cell.accessibilityValue = scenario.detail
        cell.accessibilityTraits = [.button]
        cell.accessibilityIdentifier = "scenario.\(scenario.rawValue)"
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            DemoDetailViewController(
                scenario: scenario(at: indexPath)
            ),
            animated: true
        )
    }

    private func scenario(at indexPath: IndexPath) -> DemoScenario {
        DemoScenario.scenarios(
            in: sections[indexPath.section]
        )[indexPath.row]
    }

    private func makeHeader() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "函数式解析与精准诊断"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .white

        let detailLabel = UILabel()
        detailLabel.text = "选择一个示例，在下个页面编辑 JSON、执行解析，并查看字段结果与统一监听捕获的问题。"
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        detailLabel.numberOfLines = 0

        let countLabel = UILabel()
        countLabel.text = "\(DemoScenario.allCases.count) 个可运行示例"
        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.textColor = UIColor.white.withAlphaComponent(0.75)

        let stack = UIStackView(
            arrangedSubviews: [titleLabel, detailLabel, countLabel]
        )
        stack.axis = .vertical
        stack.spacing = 8

        let header = GradientView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 170)
        )
        header.layer.cornerRadius = 18
        header.layer.masksToBounds = true
        header.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: header.topAnchor,
                constant: 20
            ),
            stack.leadingAnchor.constraint(
                equalTo: header.leadingAnchor,
                constant: 20
            ),
            stack.trailingAnchor.constraint(
                equalTo: header.trailingAnchor,
                constant: -20
            ),
            stack.bottomAnchor.constraint(
                equalTo: header.bottomAnchor,
                constant: -20
            )
        ])

        return header
    }

    private func configureDiagnosticsMenu() {
        let loggingEnabled = SafeCodableDiagnostics
            .isAutomaticLoggingEnabled
        let loggingAction = UIAction(
            title: "控制台自动打印",
            image: UIImage(systemName: "terminal"),
            state: loggingEnabled ? .on : .off
        ) { [weak self] _ in
            SafeCodableDiagnostics.isAutomaticLoggingEnabled.toggle()
            self?.configureDiagnosticsMenu()
        }

        let listenerAction = UIAction(
            title: "统一监听已启用",
            image: UIImage(systemName: "dot.radiowaves.left.and.right"),
            attributes: [.disabled],
            state: .on
        ) { _ in }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "waveform.badge.magnifyingglass"),
            menu: UIMenu(
                title: "诊断设置",
                children: [loggingAction, listenerAction]
            )
        )
    }
}

/// 示例详情页：编辑 JSON、执行解析、展示值和结构化诊断。
final class DemoDetailViewController: UIViewController {
    private let scenario: DemoScenario
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let jsonTextView = UITextView()
    private let resultStack = UIStackView()
    private let issueStack = UIStackView()
    private let statusLabel = InsetLabel()

    init(scenario: DemoScenario) {
        self.scenario = scenario
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureHierarchy()
        configureAppearance()
        configureConstraints()
        jsonTextView.text = scenario.json
        decode()
    }

    private func configureNavigation() {
        title = scenario.title
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "收起键盘",
            style: .plain,
            target: self,
            action: #selector(dismissKeyboard)
        )
    }

    private func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.addArrangedSubview(makeHeaderCard())
        contentStack.addArrangedSubview(makeJSONCard())
        contentStack.addArrangedSubview(makeDecodeButton())
        contentStack.addArrangedSubview(makeResultCard())
        contentStack.addArrangedSubview(makeIssueCard())
    }

    private func configureAppearance() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.keyboardDismissMode = .interactive

        jsonTextView.font = .monospacedSystemFont(
            ofSize: 12,
            weight: .regular
        )
        jsonTextView.backgroundColor = .secondarySystemGroupedBackground
        jsonTextView.layer.cornerRadius = 12
        jsonTextView.layer.borderWidth = 1
        jsonTextView.layer.borderColor = UIColor.separator
            .withAlphaComponent(0.35)
            .cgColor
        jsonTextView.autocapitalizationType = .none
        jsonTextView.autocorrectionType = .no
        jsonTextView.smartQuotesType = .no
        jsonTextView.smartDashesType = .no
        jsonTextView.accessibilityIdentifier = "jsonEditor"

        resultStack.axis = .vertical
        resultStack.spacing = 10
        issueStack.axis = .vertical
        issueStack.spacing = 12

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.masksToBounds = true
        statusLabel.contentInsets = .init(
            top: 5,
            left: 10,
            bottom: 5,
            right: 10
        )
    }

    private func configureConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        jsonTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 16
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: 16
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -16
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -24
            ),

            jsonTextView.heightAnchor.constraint(equalToConstant: 280)
        ])
    }

    private func makeHeaderCard() -> UIView {
        let imageView = UIImageView(
            image: UIImage(systemName: scenario.symbolName)
        )
        imageView.tintColor = .systemIndigo
        imageView.preferredSymbolConfiguration = .init(
            pointSize: 30,
            weight: .semibold
        )

        let titleLabel = UILabel()
        titleLabel.text = scenario.title
        titleLabel.font = .preferredFont(forTextStyle: .title3)

        let detailLabel = UILabel()
        detailLabel.text = scenario.detail
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let textStack = UIStackView(
            arrangedSubviews: [titleLabel, detailLabel]
        )
        textStack.axis = .vertical
        textStack.spacing = 6

        let stack = UIStackView(
            arrangedSubviews: [imageView, textStack]
        )
        stack.alignment = .center
        stack.spacing = 14
        return card(containing: stack)
    }

    private func makeJSONCard() -> UIView {
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("恢复示例", for: .normal)
        resetButton.titleLabel?.font = .preferredFont(
            forTextStyle: .caption1
        )
        resetButton.addTarget(
            self,
            action: #selector(resetJSON),
            for: .touchUpInside
        )

        let titleRow = UIStackView(arrangedSubviews: [
            makeSectionTitle("输入 JSON", symbol: "curlybraces"),
            resetButton
        ])
        titleRow.alignment = .center
        titleRow.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [titleRow, jsonTextView])
        stack.axis = .vertical
        stack.spacing = 10
        return card(containing: stack)
    }

    private func makeDecodeButton() -> UIView {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "解析当前 JSON"
        configuration.image = UIImage(systemName: "play.fill")
        configuration.imagePadding = 8
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = .systemIndigo
        configuration.contentInsets = .init(
            top: 14,
            leading: 18,
            bottom: 14,
            trailing: 18
        )

        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "decodeButton"
        button.addTarget(
            self,
            action: #selector(decode),
            for: .touchUpInside
        )
        return button
    }

    private func makeResultCard() -> UIView {
        let spacer = UIView()
        let titleRow = UIStackView(arrangedSubviews: [
            makeSectionTitle("解析结果", symbol: "list.bullet.rectangle"),
            spacer,
            statusLabel
        ])
        titleRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleRow, resultStack])
        stack.axis = .vertical
        stack.spacing = 14

        let view = card(containing: stack)
        view.accessibilityIdentifier = "decodeResult"
        return view
    }

    private func makeIssueCard() -> UIView {
        let stack = UIStackView(arrangedSubviews: [
            makeSectionTitle(
                "统一监听诊断",
                symbol: "waveform.badge.magnifyingglass"
            ),
            issueStack
        ])
        stack.axis = .vertical
        stack.spacing = 14
        let view = card(containing: stack)
        view.accessibilityIdentifier = "diagnosticResult"
        return view
    }

    private func makeSectionTitle(
        _ title: String,
        symbol: String
    ) -> UIView {
        let imageView = UIImageView(
            image: UIImage(systemName: symbol)
        )
        imageView.tintColor = .label
        imageView.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)

        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.spacing = 7
        stack.alignment = .center
        return stack
    }

    private func card(containing content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(
                equalTo: card.topAnchor,
                constant: 16
            ),
            content.leadingAnchor.constraint(
                equalTo: card.leadingAnchor,
                constant: 16
            ),
            content.trailingAnchor.constraint(
                equalTo: card.trailingAnchor,
                constant: -16
            ),
            content.bottomAnchor.constraint(
                equalTo: card.bottomAnchor,
                constant: -16
            )
        ])
        return card
    }

    private func show(_ report: DecodeReport) {
        removeArrangedSubviews(from: resultStack)
        removeArrangedSubviews(from: issueStack)

        if report.isSuccess {
            let hasIssues = !report.issues.isEmpty
            statusLabel.text = hasIssues
                ? "✓ 成功 · \(report.issues.count) 条诊断"
                : "✓ 成功"
            statusLabel.textColor = hasIssues
                ? .systemOrange
                : .systemGreen
            statusLabel.backgroundColor = (
                hasIssues
                    ? UIColor.systemOrange
                    : UIColor.systemGreen
            ).withAlphaComponent(0.12)
        } else {
            statusLabel.text = "✕ 解析失败"
            statusLabel.textColor = .systemRed
            statusLabel.backgroundColor = UIColor.systemRed
                .withAlphaComponent(0.12)
        }

        if let errorMessage = report.errorMessage {
            let label = makeMultilineLabel(
                errorMessage,
                color: .systemRed,
                monospaced: true
            )
            resultStack.addArrangedSubview(label)
        } else {
            report.fields.forEach {
                resultStack.addArrangedSubview(ResultRow(field: $0))
            }
        }

        if report.issues.isEmpty {
            issueStack.addArrangedSubview(
                makeMultilineLabel(
                    "没有触发字段回退。统一监听已启用，Release 也可静默收集。",
                    color: .secondaryLabel,
                    monospaced: false
                )
            )
        } else {
            report.issues.forEach {
                issueStack.addArrangedSubview(IssueView(issue: $0))
            }
        }
    }

    private func makeMultilineLabel(
        _ text: String,
        color: UIColor,
        monospaced: Bool
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.numberOfLines = 0
        label.font = monospaced
            ? .monospacedSystemFont(ofSize: 12, weight: .regular)
            : .preferredFont(forTextStyle: .subheadline)
        return label
    }

    private func removeArrangedSubviews(from stack: UIStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @objc private func resetJSON() {
        jsonTextView.text = scenario.json
        decode()
    }

    @objc private func decode() {
        dismissKeyboard()
        show(
            DemoDecoder.decode(
                scenario: scenario,
                json: jsonTextView.text ?? ""
            )
        )
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

private final class ResultRow: UIView {
    init(field: DecodeField) {
        super.init(frame: .zero)

        let nameLabel = UILabel()
        nameLabel.text = field.name
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.textColor = .secondaryLabel
        nameLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        let valueLabel = UILabel()
        valueLabel.text = field.value
        valueLabel.font = .monospacedSystemFont(
            ofSize: 13,
            weight: .regular
        )
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right

        let stack = UIStackView(
            arrangedSubviews: [nameLabel, valueLabel]
        )
        stack.alignment = .firstBaseline
        stack.spacing = 12

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -3
            ),
            nameLabel.widthAnchor.constraint(equalToConstant: 118)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private final class IssueView: UIView {
    init(issue: SafeDecodeIssue) {
        super.init(frame: .zero)

        backgroundColor = UIColor.systemOrange.withAlphaComponent(0.09)
        layer.cornerRadius = 12

        let codeLabel = InsetLabel()
        codeLabel.text = issue.reasonCode
        codeLabel.textColor = .systemOrange
        codeLabel.backgroundColor = UIColor.systemOrange
            .withAlphaComponent(0.14)
        codeLabel.font = .monospacedSystemFont(
            ofSize: 11,
            weight: .semibold
        )
        codeLabel.layer.cornerRadius = 8
        codeLabel.layer.masksToBounds = true
        codeLabel.contentInsets = .init(
            top: 4,
            left: 7,
            bottom: 4,
            right: 7
        )
        codeLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        let pathLabel = UILabel()
        pathLabel.text = issue.pathDescription
        pathLabel.font = .monospacedSystemFont(
            ofSize: 11,
            weight: .regular
        )
        pathLabel.textColor = .secondaryLabel
        pathLabel.numberOfLines = 0

        let titleRow = UIStackView(
            arrangedSubviews: [codeLabel, pathLabel]
        )
        titleRow.alignment = .center
        titleRow.spacing = 8

        let messageLabel = UILabel()
        messageLabel.text = issue.message
        messageLabel.font = .preferredFont(forTextStyle: .caption1)
        messageLabel.numberOfLines = 0

        let stack = UIStackView(
            arrangedSubviews: [titleRow, messageLabel]
        )
        stack.axis = .vertical
        stack.spacing = 8

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 12
            ),
            stack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -12
            ),
            stack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -12
            )
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private final class GradientView: UIView {
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let gradient = layer as? CAGradientLayer else {
            return
        }
        gradient.colors = [
            UIColor.systemIndigo.cgColor,
            UIColor.systemBlue.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private final class InsetLabel: UILabel {
    var contentInsets = UIEdgeInsets.zero {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
