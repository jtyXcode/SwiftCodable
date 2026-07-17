import UIKit

final class DemoViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let scenarioControl = UISegmentedControl(
        items: DemoScenario.allCases.map(\.title)
    )
    private let scenarioDetailLabel = UILabel()
    private let jsonTextView = UITextView()
    private let resultStack = UIStackView()
    private let statusLabel = InsetLabel()

    private var scenario: DemoScenario = .device
    private var hasPositionedInitialContent = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureHierarchy()
        configureAppearance()
        configureConstraints()
        loadScenario(.device)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPositionedInitialContent else {
            return
        }

        hasPositionedInitialContent = true
        scrollView.setContentOffset(
            CGPoint(x: 0, y: -scrollView.adjustedContentInset.top),
            animated: false
        )
    }

    private func configureNavigation() {
        title = "SwiftCodable"
        navigationController?.navigationBar.prefersLargeTitles = false
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

        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeScenarioCard())
        contentStack.addArrangedSubview(makeJSONCard())
        contentStack.addArrangedSubview(makeDecodeButton())
        contentStack.addArrangedSubview(makeResultCard())
    }

    private func configureAppearance() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.keyboardDismissMode = .interactive

        scenarioControl.selectedSegmentIndex = 0
        scenarioControl.accessibilityIdentifier = "scenarioPicker"
        scenarioControl.addTarget(
            self,
            action: #selector(scenarioChanged),
            for: .valueChanged
        )

        scenarioDetailLabel.font = .preferredFont(forTextStyle: .caption1)
        scenarioDetailLabel.textColor = .secondaryLabel
        scenarioDetailLabel.numberOfLines = 0

        jsonTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
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

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.masksToBounds = true
        statusLabel.contentInsets = .init(top: 5, left: 10, bottom: 5, right: 10)
    }

    private func configureConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        jsonTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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

    private func makeHeader() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "✓  Property Wrapper 测试台"
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.textColor = .white

        let detailLabel = UILabel()
        detailLabel.text = "修改 JSON，观察缺失、null、脏类型和多层嵌套的容错结果。"
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 8

        let header = GradientView()
        header.layer.cornerRadius = 18
        header.layer.masksToBounds = true
        header.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -18)
        ])

        return header
    }

    private func makeScenarioCard() -> UIView {
        let stack = UIStackView(arrangedSubviews: [
            makeSectionTitle("测试场景", symbol: "square.grid.2x2"),
            scenarioControl,
            scenarioDetailLabel
        ])
        stack.axis = .vertical
        stack.spacing = 10
        return card(containing: stack)
    }

    private func makeJSONCard() -> UIView {
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("恢复示例", for: .normal)
        resetButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
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
        configuration.title = "重新解码"
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
        button.addTarget(self, action: #selector(decode), for: .touchUpInside)
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

        let resultCard = card(containing: stack)
        resultCard.accessibilityIdentifier = "decodeResult"
        return resultCard
    }

    private func makeSectionTitle(_ title: String, symbol: String) -> UIView {
        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.tintColor = .label
        imageView.setContentHuggingPriority(.required, for: .horizontal)

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
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func loadScenario(_ scenario: DemoScenario) {
        self.scenario = scenario
        scenarioDetailLabel.text = scenario.detail
        jsonTextView.text = scenario.json
        decode()
    }

    private func show(_ report: DecodeReport) {
        resultStack.arrangedSubviews.forEach {
            resultStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        statusLabel.text = report.isSuccess ? "✓ 成功" : "✕ 失败"
        statusLabel.textColor = report.isSuccess ? .systemGreen : .systemRed
        statusLabel.backgroundColor = (
            report.isSuccess ? UIColor.systemGreen : UIColor.systemRed
        ).withAlphaComponent(0.12)

        if let errorMessage = report.errorMessage {
            let label = UILabel()
            label.text = errorMessage
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = .systemRed
            label.numberOfLines = 0
            resultStack.addArrangedSubview(label)
            return
        }

        report.fields.forEach { field in
            resultStack.addArrangedSubview(ResultRow(field: field))
        }
    }

    @objc private func scenarioChanged() {
        guard DemoScenario.allCases.indices.contains(
            scenarioControl.selectedSegmentIndex
        ) else {
            return
        }

        loadScenario(
            DemoScenario.allCases[scenarioControl.selectedSegmentIndex]
        )
    }

    @objc private func resetJSON() {
        jsonTextView.text = scenario.json
        decode()
    }

    @objc private func decode() {
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
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = field.value
        valueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        stack.alignment = .firstBaseline
        stack.distribution = .fill
        stack.spacing = 12

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            nameLabel.widthAnchor.constraint(equalToConstant: 112)
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
        configureGradient()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configureGradient() {
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
