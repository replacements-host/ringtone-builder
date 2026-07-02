import AVFoundation

/// Reads an audio asset's samples and downsamples them into a small number
/// of amplitude points suitable for drawing a waveform, regardless of song length.
enum WaveformGenerator {
    static let pointCount = 300

    enum WaveformError: Error {
        case noAudioTrack
        case readerSetupFailed
    }

    static func generate(for asset: AVURLAsset) async throws -> [Float] {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw WaveformError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        guard reader.canAdd(output) else {
            throw WaveformError.readerSetupFailed
        }
        reader.add(output)
        reader.startReading()

        var sampleData = [Int16]()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = [Int16](repeating: 0, count: length / MemoryLayout<Int16>.size)
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
            sampleData.append(contentsOf: data)
        }

        guard reader.status == .completed || !sampleData.isEmpty else {
            throw WaveformError.readerSetupFailed
        }

        return downsample(sampleData, to: pointCount)
    }

    private static func downsample(_ samples: [Int16], to targetCount: Int) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let bucketSize = max(1, samples.count / targetCount)
        var result = [Float]()
        result.reserveCapacity(targetCount)

        var index = 0
        while index < samples.count {
            let end = min(index + bucketSize, samples.count)
            var peak: Float = 0
            for i in index..<end {
                let magnitude = abs(Float(samples[i]) / Float(Int16.max))
                peak = max(peak, magnitude)
            }
            result.append(peak)
            index = end
        }
        return result
    }
}
