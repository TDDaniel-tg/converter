import Foundation

// MARK: - Conversion Result
enum ConversionResult {
    case success(converted: Int)
    case partial(converted: Int, failed: Int, message: String?)
    case failure(error: String)
}
