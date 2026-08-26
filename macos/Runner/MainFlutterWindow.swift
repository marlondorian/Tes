import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  var nativeControlManager: NativeControlManager?
  var scaffoldChannelManager: ScaffoldChannelManager?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    nativeControlManager = NativeControlManager(containerView: flutterViewController.view)
    nativeControlManager?.setupChannels(binaryMessenger: flutterViewController.engine.binaryMessenger)

    scaffoldChannelManager = ScaffoldChannelManager(window: self, containerView: flutterViewController.view)
    scaffoldChannelManager?.setupChannel(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

class ScaffoldChannelManager: NSObject, NSToolbarDelegate {
    private weak var window: NSWindow?
    private weak var containerView: NSView?
    private var scaffoldChannel: FlutterMethodChannel?

    private var toolbar: NSToolbar?
    private var currentActions: [[String: Any]] = []
    private var showBackButton: Bool = false
    private var isHeaderVisible: Bool = true

    private var bottomNavContainer: NSView?
    private var segmentedControl: NSSegmentedControl?
    private var isBottomNavVisible: Bool = false

    init(window: NSWindow, containerView: NSView) {
        self.window = window
        self.containerView = containerView
        super.init()
    }

    func setupChannel(binaryMessenger: FlutterBinaryMessenger) {
        scaffoldChannel = FlutterMethodChannel(name: "com.example.macos_native_widgets/scaffold", binaryMessenger: binaryMessenger)
        scaffoldChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "updateHeaderBar":
                if let args = call.arguments as? [String: Any] {
                    let title = args["title"] as? String ?? ""
                    let subtitle = args["subtitle"] as? String ?? ""
                    let showBack = args["showBackButton"] as? Bool ?? false
                    self.window?.title = title
                    if #available(macOS 11.0, *) {
                        self.window?.subtitle = subtitle
                    }
                    if let colorStr = args["backgroundColor"] as? String, let color = self.parseCssColor(colorStr) {
                        self.window?.backgroundColor = color
                    }
                    self.showBackButton = showBack
                    self.updateToolbar()
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for updateHeaderBar", details: nil))
                }

            case "setHeaderBarVisibility":
                if let args = call.arguments as? [String: Any],
                   let visible = args["visible"] as? Bool {
                    self.isHeaderVisible = visible
                    if visible {
                        self.updateToolbar()
                    } else {
                        self.window?.toolbar = nil
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setHeaderBarVisibility", details: nil))
                }

            case "setHeaderActions":
                if let actions = call.arguments as? [[String: Any]] {
                    self.currentActions = actions
                    self.updateToolbar()
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setHeaderActions", details: nil))
                }

            case "getHeaderBarHeight":
                // Transparent macOS toolbar overlays top of content frame
                result(0)

            case "setupBottomNav":
                if let args = call.arguments as? [String: Any],
                   let selectedIndex = args["selectedIndex"] as? Int,
                   let items = args["items"] as? [[String: Any]] {
                    self.setupBottomNav(selectedIndex: selectedIndex, items: items)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setupBottomNav", details: nil))
                }

            case "setBottomNavVisibility":
                if let args = call.arguments as? [String: Any],
                   let visible = args["visible"] as? Bool {
                    self.isBottomNavVisible = visible
                    self.bottomNavContainer?.isHidden = !visible
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setBottomNavVisibility", details: nil))
                }

            case "applyCustomCss":
                // GTK-specific custom CSS is ignored on macOS
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func updateToolbar() {
        guard let window = window, isHeaderVisible else { return }

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        let toolbarId = NSToolbar.Identifier("MainAppToolbar_\(UUID().uuidString)")
        let newToolbar = NSToolbar(identifier: toolbarId)
        newToolbar.delegate = self
        newToolbar.displayMode = .iconOnly
        newToolbar.allowsUserCustomization = false
        self.toolbar = newToolbar
        window.toolbar = newToolbar
    }

    // MARK: - NSToolbarDelegate

    private var itemIdentifiers: [NSToolbarItem.Identifier] {
        var list: [NSToolbarItem.Identifier] = []
        var addedIds = Set<String>()

        if showBackButton {
            list.append(NSToolbarItem.Identifier("back"))
            addedIds.insert("back")
        }

        for action in currentActions {
            let id = action["id"] as? String ?? ""
            let pos = action["position"] as? String ?? "end"
            if pos == "start" && !addedIds.contains(id) {
                list.append(NSToolbarItem.Identifier(id))
                addedIds.insert(id)
            }
        }

        list.append(.flexibleSpace)
        list.append(NSToolbarItem.Identifier("title"))
        list.append(.flexibleSpace)

        for action in currentActions {
            let id = action["id"] as? String ?? ""
            let pos = action["position"] as? String ?? "end"
            if pos != "start" && !addedIds.contains(id) {
                list.append(NSToolbarItem.Identifier(id))
                addedIds.insert(id)
            }
        }

        return list
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return itemIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return itemIdentifiers
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let idStr = itemIdentifier.rawValue

        if idStr == "title" {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .centerX
            container.spacing = 1

            let titleStr = window?.title ?? ""
            if !titleStr.isEmpty {
                let titleLabel = NSTextField(labelWithString: titleStr)
                titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
                titleLabel.textColor = NSColor.labelColor
                titleLabel.alignment = .center
                container.addArrangedSubview(titleLabel)
            }

            if #available(macOS 11.0, *), let sub = window?.subtitle, !sub.isEmpty {
                let subLabel = NSTextField(labelWithString: sub)
                subLabel.font = NSFont.systemFont(ofSize: 10)
                subLabel.textColor = NSColor.secondaryLabelColor
                subLabel.alignment = .center
                container.addArrangedSubview(subLabel)
            }

            item.view = container
            return item
        }

        if idStr == "back" {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let action = currentActions.first(where: { ($0["id"] as? String) == "back" })
            let label = action?["label"] as? String ?? "Back"
            let iconName = action?["iconName"] as? String ?? "go-previous-symbolic"

            item.label = label.isEmpty ? "Back" : label
            item.paletteLabel = item.label
            item.toolTip = item.label
            let sfName = mapGtkIconToSFSymbol(iconName) ?? "chevron.left"
            if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: sfName, accessibilityDescription: item.label) {
                item.image = image
            }
            item.target = self
            item.action = #selector(onToolbarItemClicked(_:))
            return item
        }

        guard let action = currentActions.first(where: { ($0["id"] as? String) == idStr }) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        let type = action["type"] as? String ?? "action"
        let label = action["label"] as? String ?? ""
        item.label = label
        item.paletteLabel = label
        item.toolTip = label

        if type == "search" {
            let placeholder = action["placeholder"] as? String ?? "Search..."
            let val = action["value"] as? String ?? ""
            let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
            searchField.identifier = NSUserInterfaceItemIdentifier(idStr)
            searchField.placeholderString = placeholder
            searchField.stringValue = val
            searchField.target = self
            searchField.action = #selector(onHeaderSearchSubmitted(_:))
            item.view = searchField
            return item
        }

        if type == "tabbar" {
            let tabs = action["tabs"] as? [String] ?? []
            let selectedIndex = action["selectedIndex"] as? Int ?? 0
            let segControl = NSSegmentedControl()
            segControl.identifier = NSUserInterfaceItemIdentifier(idStr)
            segControl.segmentCount = tabs.count
            segControl.trackingMode = .selectOne
            for (i, tStr) in tabs.enumerated() {
                segControl.setLabel(tStr, forSegment: i)
            }
            if selectedIndex < tabs.count {
                segControl.selectedSegment = selectedIndex
            }
            segControl.target = self
            segControl.action = #selector(onHeaderTabChanged(_:))
            item.view = segControl
            return item
        }

        if type == "title" {
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .centerX
            container.spacing = 1

            let titleStr = action["title"] as? String ?? ""
            if !titleStr.isEmpty {
                let titleLabel = NSTextField(labelWithString: titleStr)
                titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
                titleLabel.textColor = NSColor.labelColor
                titleLabel.alignment = .center
                container.addArrangedSubview(titleLabel)
            }

            let sub = action["subtitle"] as? String ?? ""
            if !sub.isEmpty {
                let subLabel = NSTextField(labelWithString: sub)
                subLabel.font = NSFont.systemFont(ofSize: 10)
                subLabel.textColor = NSColor.secondaryLabelColor
                subLabel.alignment = .center
                container.addArrangedSubview(subLabel)
            }

            item.view = container
            return item
        }

        let iconName = action["iconName"] as? String
        if #available(macOS 11.0, *), let sfName = mapGtkIconToSFSymbol(iconName), let image = NSImage(systemSymbolName: sfName, accessibilityDescription: label) {
            item.image = image
        } else if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: label)
        }

        item.target = self
        item.action = #selector(onToolbarItemClicked(_:))
        return item
    }

    @objc private func onToolbarItemClicked(_ sender: NSToolbarItem) {
        let id = sender.itemIdentifier.rawValue
        if id == "back" {
            scaffoldChannel?.invokeMethod("onHeaderBack", arguments: nil)
        } else {
            scaffoldChannel?.invokeMethod("onHeaderActionPressed", arguments: ["id": id])
        }
    }

    @objc private func onHeaderSearchSubmitted(_ sender: NSSearchField) {
        let itemId = sender.identifier?.rawValue ?? "search"
        scaffoldChannel?.invokeMethod("onHeaderSearchSubmitted", arguments: ["id": itemId, "text": sender.stringValue])
    }

    @objc private func onHeaderTabChanged(_ sender: NSSegmentedControl) {
        let itemId = sender.identifier?.rawValue ?? "tabbar"
        scaffoldChannel?.invokeMethod("onHeaderTabSelected", arguments: ["id": itemId, "index": sender.selectedSegment])
    }

    // MARK: - Bottom Navigation

    private func setupBottomNav(selectedIndex: Int, items: [[String: Any]]) {
        guard let container = containerView else { return }

        if bottomNavContainer == nil {
            let navBar = NSView()
            navBar.wantsLayer = true
            navBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            bottomNavContainer = navBar
            container.addSubview(navBar, positioned: .above, relativeTo: nil)
        }

        guard let navBar = bottomNavContainer else { return }

        navBar.subviews.forEach { $0.removeFromSuperview() }

        let segControl = NSSegmentedControl()
        segControl.segmentCount = items.count
        segControl.trackingMode = .selectOne
        segControl.target = self
        segControl.action = #selector(onSegmentChanged(_:))

        for (i, item) in items.enumerated() {
            let label = item["label"] as? String ?? ""
            let iconName = item["iconName"] as? String
            segControl.setLabel(label, forSegment: i)
            if #available(macOS 11.0, *), let sfName = mapGtkIconToSFSymbol(iconName), let image = NSImage(systemSymbolName: sfName, accessibilityDescription: label) {
                segControl.setImage(image, forSegment: i)
            }
        }

        if selectedIndex >= 0 && selectedIndex < items.count {
            segControl.selectedSegment = selectedIndex
        }

        segControl.sizeToFit()
        segmentedControl = segControl
        navBar.addSubview(segControl)

        updateBottomNavLayout()
    }

    private func updateBottomNavLayout() {
        guard let container = containerView, let navBar = bottomNavContainer else { return }
        let height: CGFloat = 48.0
        let width = container.bounds.width
        let y: CGFloat = container.isFlipped ? container.bounds.height - height : 0

        navBar.frame = NSRect(x: 0, y: y, width: width, height: height)
        var mask = NSView.AutoresizingMask(rawValue: 2) // widthSizable
        if container.isFlipped {
            mask.insert(NSView.AutoresizingMask(rawValue: 8)) // minYMargin
        } else {
            mask.insert(NSView.AutoresizingMask(rawValue: 32)) // maxYMargin
        }
        navBar.autoresizingMask = mask

        if let seg = segmentedControl {
            seg.sizeToFit()
            let segWidth = seg.frame.width
            let segHeight = seg.frame.height
            seg.frame = NSRect(x: (width - segWidth) / 2.0, y: (height - segHeight) / 2.0, width: segWidth, height: segHeight)
            seg.autoresizingMask = [
                NSView.AutoresizingMask(rawValue: 1),  // minXMargin
                NSView.AutoresizingMask(rawValue: 4),  // maxXMargin
                NSView.AutoresizingMask(rawValue: 8),  // minYMargin
                NSView.AutoresizingMask(rawValue: 32)  // maxYMargin
            ]
        }
    }

    @objc private func onSegmentChanged(_ sender: NSSegmentedControl) {
        scaffoldChannel?.invokeMethod("onBottomNavSelected", arguments: ["index": sender.selectedSegment])
    }

    // MARK: - Helpers

    private func mapGtkIconToSFSymbol(_ iconName: String?) -> String? {
        guard let icon = iconName else { return nil }
        switch icon {
        case "go-previous-symbolic", "pan-start-symbolic": return "chevron.left"
        case "go-next-symbolic", "pan-end-symbolic": return "chevron.right"
        case "view-refresh-symbolic": return "arrow.clockwise"
        case "dialog-information-symbolic": return "info.circle"
        case "go-home-symbolic": return "house"
        case "edit-symbolic": return "pencil"
        case "emblem-system-symbolic", "preferences-system-symbolic": return "gear"
        case "document-open-symbolic": return "doc"
        case "folder-symbolic": return "folder"
        case "list-add-symbolic": return "plus"
        case "user-trash-symbolic": return "trash"
        default: return nil
        }
    }

    private func parseCssColor(_ css: String) -> NSColor? {
        if css.isEmpty { return nil }
        if css.hasPrefix("rgba(") && css.hasSuffix(")") {
            let componentsStr = css.dropFirst(5).dropLast(1)
            let parts = componentsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 4,
               let r = Double(parts[0]),
               let g = Double(parts[1]),
               let b = Double(parts[2]),
               let a = Double(parts[3]) {
                return NSColor(srgbRed: CGFloat(r / 255.0), green: CGFloat(g / 255.0), blue: CGFloat(b / 255.0), alpha: CGFloat(a))
            }
        }
        return nil
    }
}

class NativeControlManager: NSObject {
    private var buttons: [String: NSButton] = [:]
    private var switches: [String: NSSwitch] = [:]
    private var inputs: [String: NSTextField] = [:]
    private weak var containerView: NSView?
    private var buttonChannel: FlutterMethodChannel?
    private var switchChannel: FlutterMethodChannel?

    init(containerView: NSView) {
        self.containerView = containerView
        super.init()
    }

    func setupChannels(binaryMessenger: FlutterBinaryMessenger) {
        setupButtonChannel(binaryMessenger: binaryMessenger)
        setupSwitchChannel(binaryMessenger: binaryMessenger)
    }

    private func setupButtonChannel(binaryMessenger: FlutterBinaryMessenger) {
        buttonChannel = FlutterMethodChannel(name: "com.example.macos_native_widgets/button", binaryMessenger: binaryMessenger)
        buttonChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {

            case "createButton":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let title = args["title"] as? String,
                   let x = args["x"] as? Double,
                   let y = args["y"] as? Double {
                    if let existing = buttons[id] {
                        existing.title = title
                        existing.sizeToFit()
                        let size = existing.intrinsicContentSize
                        if let container = self.containerView {
                            self.position(view: existing, x: x, y: y, in: container)
                        }
                        result(["width": size.width, "height": size.height])
                    } else {
                        let size = self.createButton(id: id, title: title, x: x, y: y)
                        result(["width": size.width, "height": size.height])
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for createButton", details: nil))
                }
            case "updatePosition":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let x = args["x"] as? Double,
                   let y = args["y"] as? Double {
                    self.updatePosition(id: id, x: x, y: y)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for updatePosition", details: nil))
                }
            case "removeButton":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String {
                    self.removeButton(id: id)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for removeButton", details: nil))
                }
            case "setVisibility":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let visible = args["visible"] as? Bool {
                    if let button = self.buttons[id] {
                        button.isHidden = !visible
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setVisibility", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupSwitchChannel(binaryMessenger: FlutterBinaryMessenger) {
        switchChannel = FlutterMethodChannel(name: "com.example.macos_native_widgets/native", binaryMessenger: binaryMessenger)
        switchChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "createInput":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let text = args["text"] as? String,
                   let x = args["x"] as? Double,
                   let y = args["y"] as? Double {
                    let width = args["width"] as? Double
                    let height = args["height"] as? Double
                    if let existing = inputs[id] {
                        existing.stringValue = text
                        if let w = width, let h = height {
                            existing.frame.size = NSSize(width: CGFloat(w), height: CGFloat(h))
                        } else {
                            existing.sizeToFit()
                        }
                        let size = existing.frame.size
                        if let container = self.containerView {
                            self.position(view: existing, x: x, y: y, in: container)
                        }
                        result(["width": size.width, "height": size.height])
                    } else {
                        let size = self.createInput(id: id, text: text, x: x, y: y, width: width, height: height)
                        result(["width": size.width, "height": size.height])
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for createInput", details: nil))
                }
                return
            case "createSwitch":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let value = args["value"] as? Bool,
                   let x = args["x"] as? Double,
                   let y = args["y"] as? Double {
                    if let existing = switches[id] {
                        existing.state = value ? .on : .off
                        existing.sizeToFit()
                        let size = existing.intrinsicContentSize
                        if let container = self.containerView {
                            self.position(view: existing, x: x, y: y, in: container)
                        }
                        result(["width": size.width, "height": size.height])
                    } else {
                        let size = self.createSwitch(id: id, value: value, x: x, y: y)
                        result(["width": size.width, "height": size.height])
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for createSwitch", details: nil))
                }
            case "updatePosition":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let x = args["x"] as? Double,
                   let y = args["y"] as? Double {
                    self.updatePosition(id: id, x: x, y: y)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for updatePosition", details: nil))
                }
            case "removeSwitch":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String {
                    self.removeSwitch(id: id)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for removeSwitch", details: nil))
                }
            case "removeInput":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String {
                    self.removeInput(id: id)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for removeInput", details: nil))
                }
                return
            case "setVisibility":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let visible = args["visible"] as? Bool {
                    if let nativeSwitch = self.switches[id] {
                        nativeSwitch.isHidden = !visible
                    } else if let input = self.inputs[id] {
                        input.isHidden = !visible
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for setVisibility", details: nil))
                }
            case "updateSwitchValue":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let value = args["value"] as? Bool {
                    self.updateSwitchValue(id: id, value: value)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments for updateSwitchValue", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func createButton(id: String, title: String, x: Double, y: Double) -> NSSize {
        let button = NSButton(title: title, target: self, action: #selector(onButtonPressed(_:)))
        button.bezelStyle = .rounded

        button.sizeToFit()
        let size = button.intrinsicContentSize

        button.identifier = NSUserInterfaceItemIdentifier(id)

        buttons[id] = button
        if let container = containerView {
            container.addSubview(button)
            updatePosition(id: id, x: x, y: y)
        }

        return size
    }

    private func createSwitch(id: String, value: Bool, x: Double, y: Double) -> NSSize {
        let nativeSwitch = NSSwitch()
        nativeSwitch.state = value ? .on : .off
        nativeSwitch.target = self
        nativeSwitch.action = #selector(onSwitchChanged(_:))
        nativeSwitch.identifier = NSUserInterfaceItemIdentifier(id)

        nativeSwitch.sizeToFit()
        let size = nativeSwitch.intrinsicContentSize

        switches[id] = nativeSwitch
        if let container = containerView {
            container.addSubview(nativeSwitch)
            updatePosition(id: id, x: x, y: y)
        }

        return size
    }

    private func createInput(id: String, text: String, x: Double, y: Double, width: Double? = nil, height: Double? = nil) -> NSSize {
        let input = NSTextField(string: text)
        input.isBordered = true
        input.isBezeled = true
        input.drawsBackground = true
        input.isEditable = true
        input.identifier = NSUserInterfaceItemIdentifier(id)
        input.delegate = self
        input.focusRingType = .default

        input.sizeToFit()
        var size = input.frame.size
        if let w = width, let h = height {
            size = NSSize(width: CGFloat(w), height: CGFloat(h))
        }
        let minWidth: CGFloat = 80
        if size.width < minWidth {
            size.width = minWidth
        }

        input.backgroundColor = NSColor.controlBackgroundColor
        input.textColor = NSColor.controlTextColor

        input.wantsLayer = true
        input.layer?.zPosition = 1000

        inputs[id] = input
        if let container = containerView {
            input.frame.size = size
            container.addSubview(input, positioned: .above, relativeTo: nil)
            updatePosition(id: id, x: x, y: y)
        }

        return size
    }

    private func updatePosition(id: String, x: Double, y: Double) {
        if let button = buttons[id], let container = containerView {
            position(view: button, x: x, y: y, in: container)
            return
        }

        if let nativeSwitch = switches[id], let container = containerView {
            position(view: nativeSwitch, x: x, y: y, in: container)
            return
        }
        
        if let input = inputs[id], let container = containerView {
            position(view: input, x: x, y: y, in: container)
            return
        }
    }

    private func position(view: NSView, x: Double, y: Double, in container: NSView) {
        var size = view.frame.size
        if size.width == 0 || size.height == 0 {
            size = view.intrinsicContentSize
        }
        guard size.width > 0 && size.height > 0 else { return }

        if container.isFlipped {
            view.frame = NSRect(x: CGFloat(x), y: CGFloat(y), width: size.width, height: size.height)
        } else {
            let invertedY = container.bounds.height - CGFloat(y) - size.height
            view.frame = NSRect(x: CGFloat(x), y: invertedY, width: size.width, height: size.height)
        }
    }

    private func removeButton(id: String) {
        if let button = buttons[id] {
            button.removeFromSuperview()
            buttons.removeValue(forKey: id)
        }
    }

    private func removeSwitch(id: String) {
        if let nativeSwitch = switches[id] {
            nativeSwitch.removeFromSuperview()
            switches.removeValue(forKey: id)
        }
    }

    private func removeInput(id: String) {
        if let input = inputs[id] {
            input.removeFromSuperview()
            inputs.removeValue(forKey: id)
        }
    }

    private func updateSwitchValue(id: String, value: Bool) {
        guard let nativeSwitch = switches[id] else { return }
        nativeSwitch.state = value ? .on : .off
    }

    @objc private func onButtonPressed(_ sender: NSButton) {
        if let id = sender.identifier?.rawValue {
            buttonChannel?.invokeMethod("onButtonPressed", arguments: ["id": id])
        }
    }

    @objc private func onSwitchChanged(_ sender: NSSwitch) {
        if let id = sender.identifier?.rawValue {
            switchChannel?.invokeMethod("onSwitchChanged", arguments: ["id": id, "value": sender.state == .on])
        }
    }
}

extension NativeControlManager: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, let id = field.identifier?.rawValue else { return }
        switchChannel?.invokeMethod("onInput", arguments: ["id": id, "value": field.stringValue])
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, let id = field.identifier?.rawValue else { return }
        switchChannel?.invokeMethod("onSubmit", arguments: ["id": id, "value": field.stringValue])
    }
}

