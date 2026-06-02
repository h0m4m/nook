import Foundation
import Supabase

final class StorageService: Sendable {
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> URL {
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"

        _ = try await supabase.storage
            .from("avatars")
            .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)

        // The path is fixed (upsert), so the URL is identical every upload and
        // image caches would keep serving the stale avatar. Append a cache-busting
        // version so the new image actually loads.
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        return components?.url ?? publicURL
    }

    func uploadImage(bucket: String, userId: UUID, fileName: String, data: Data) async throws -> URL {
        let path = "\(userId.uuidString.lowercased())/\(fileName)"

        _ = try await supabase.storage
            .from(bucket)
            .upload(path, data: data, options: .init(contentType: "image/jpeg", upsert: true))

        return try supabase.storage
            .from(bucket)
            .getPublicURL(path: path)
    }
}
