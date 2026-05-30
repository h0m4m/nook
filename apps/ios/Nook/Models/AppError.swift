import Foundation

enum AppError: LocalizedError {
    case networkError(URLError)
    case rateLimited
    case unauthorized
    case notFound
    case clientError(String)
    case serverError(Int)
    case supabaseError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            if error.code == .notConnectedToInternet {
                return "No internet connection."
            }
            if error.code == .timedOut {
                return "Request timed out. Try again."
            }
            return "Network error. Check your connection."
        case .rateLimited:
            return "Too many requests. Try again in a moment."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .notFound:
            return "Content not found."
        case .clientError(let message):
            return message
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .supabaseError(let message):
            return message
        case .unknown:
            return "Something went wrong. Try again."
        }
    }

    init(from error: Error) {
        if let appError = error as? AppError {
            self = appError
            return
        }
        if let urlError = error as? URLError {
            self = .networkError(urlError)
            return
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            self = .networkError(URLError(URLError.Code(rawValue: nsError.code)))
            return
        }
        self = .unknown(error)
    }
}
