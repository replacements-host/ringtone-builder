import AVFoundation

/// Exports a trimmed clip of an audio asset as a `.m4r` ringtone file.
enum RingtoneExporter {
    enum ExportError: LocalizedError {
        case sessionCreationFailed
        case exportFailed(underlying: Error?)
        case cancelled
        case renameFailed

        var errorDescription: String? {
            switch self {
            case .sessionCreationFailed:
                return "Couldn't prepare this song for export. Try a different song."
            case .exportFailed(let underlying):
                return "Export failed" + (underlying.map { ": \($0.localizedDescription)" } ?? ".")
            case .cancelled:
                return "Export was cancelled."
            case .renameFailed:
                return "Couldn't finish saving the ringtone file."
            }
        }
    }

    /// Exports `selection` of `asset` to a `.m4r` file in the app's Documents directory.
    static func export(asset: AVURLAsset, selection: TrimSelection) async throws -> URL {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.sessionCreationFailed
        }

        let startTime = CMTime(seconds: selection.start, preferredTimescale: 600)
        let endTime = CMTime(seconds: selection.end, preferredTimescale: 600)
        session.timeRange = CMTimeRange(start: startTime, end: endTime)
        session.outputFileType = .m4a

        if selection.fadeEnabled {
            session.audioMix = try await makeFadeAudioMix(asset: asset, selection: selection)
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let m4aURL = documentsURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        session.outputURL = m4aURL

        await session.export()

        switch session.status {
        case .completed:
            break
        case .cancelled:
            throw ExportError.cancelled
        default:
            throw ExportError.exportFailed(underlying: session.error)
        }

        let m4rURL = m4aURL.deletingPathExtension().appendingPathExtension("m4r")
        do {
            if FileManager.default.fileExists(atPath: m4rURL.path) {
                try FileManager.default.removeItem(at: m4rURL)
            }
            try FileManager.default.moveItem(at: m4aURL, to: m4rURL)
        } catch {
            throw ExportError.renameFailed
        }

        return m4rURL
    }

    /// A ~1.5s fade-in at the start of the selection and fade-out at the end.
    private static func makeFadeAudioMix(asset: AVURLAsset, selection: TrimSelection) async throws -> AVMutableAudioMix {
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            return AVMutableAudioMix()
        }

        let params = AVMutableAudioMixInputParameters(track: track)
        let fade = TrimSelection.fadeDuration
        let timescale: CMTimeScale = 600

        let selectionStart = CMTime(seconds: selection.start, preferredTimescale: timescale)
        let selectionEnd = CMTime(seconds: selection.end, preferredTimescale: timescale)
        let fadeDuration = CMTime(seconds: min(fade, selection.duration / 2), preferredTimescale: timescale)

        let fadeInRange = CMTimeRange(start: selectionStart, duration: fadeDuration)
        params.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: fadeInRange)

        let fadeOutStart = selectionEnd - fadeDuration
        let fadeOutRange = CMTimeRange(start: fadeOutStart, duration: fadeDuration)
        params.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: fadeOutRange)

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }
}
