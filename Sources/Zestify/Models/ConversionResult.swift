import Foundation

// MARK: - Conversion Result
enum ConversionResult {
    case success(outputUrls: [URL])
    case partial(converted: Int, failed: Int, message: String?)
    case failure(error: String)
}
