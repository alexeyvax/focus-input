import Carbon.HIToolbox
import Foundation

protocol InputSourceSelecting {
    var currentInputSourceID: String? { get }
    func selectInputSource(withID id: String) throws
}

enum InputSourceControllerError: LocalizedError {
    case sourceMissing(String)
    case selectionFailed(String, OSStatus)

    var errorDescription: String? {
        switch self {
        case let .sourceMissing(id):
            return "The selected input source is unavailable (\(id))."
        case let .selectionFailed(id, status):
            return "Could not select input source \(id) (error \(status))."
        }
    }
}

final class InputSourceController: InputSourceSelecting {
    var selectableInputSources: [InputSource] {
        let sources = sourceRecords()
            .map(\.model)
        let nameCounts = Dictionary(grouping: sources, by: \.name).mapValues(\.count)

        return sources
            .map { source in
                guard nameCounts[source.name, default: 0] > 1 else { return source }
                return InputSource(
                    id: source.id,
                    name: "\(source.name) — \(source.id)"
                )
            }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison == .orderedSame { return lhs.id < rhs.id }
                return comparison == .orderedAscending
            }
    }

    var currentInputSourceID: String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return stringProperty(kTISPropertyInputSourceID, of: source)
    }

    func selectInputSource(withID id: String) throws {
        guard currentInputSourceID != id else { return }
        guard let source = sourceRecords().first(where: {
            $0.model.id == id
        })?.source else {
            throw InputSourceControllerError.sourceMissing(id)
        }

        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw InputSourceControllerError.selectionFailed(id, status)
        }
    }

    private struct SourceRecord {
        let source: TISInputSource
        let model: InputSource
    }

    private func sourceRecords() -> [SourceRecord] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return []
        }

        return (sourceList as NSArray).compactMap { value in
            let cfValue = value as CFTypeRef
            guard CFGetTypeID(cfValue) == TISInputSourceGetTypeID() else { return nil }
            let source = unsafeBitCast(cfValue, to: TISInputSource.self)

            guard stringProperty(kTISPropertyInputSourceCategory, of: source)
                    == (kTISCategoryKeyboardInputSource as String),
                  boolProperty(kTISPropertyInputSourceIsSelectCapable, of: source) == true,
                  let id = stringProperty(kTISPropertyInputSourceID, of: source),
                  let name = stringProperty(kTISPropertyLocalizedName, of: source)
            else {
                return nil
            }

            return SourceRecord(
                source: source,
                model: InputSource(id: id, name: name)
            )
        }
    }

    private func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        property(key, of: source) as? String
    }

    private func boolProperty(_ key: CFString, of source: TISInputSource) -> Bool? {
        property(key, of: source) as? Bool
    }

    private func property(_ key: CFString, of source: TISInputSource) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}
