import Foundation

// MARK: - ModifierKeyDebouncer
/// Prevents false positives by requiring modifier keys to be held for a minimum duration
/// before the radial wheel is shown.
final class ModifierKeyDebouncer {

    private var workItem: DispatchWorkItem?

    init() {}

    /// Schedule action after configured delay. Cancels any pending action first.
    func schedule(action: @escaping () -> Void) {
        cancel()
        let delay = Preferences.shared.debounceDelay
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Cancel any pending scheduled action.
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
