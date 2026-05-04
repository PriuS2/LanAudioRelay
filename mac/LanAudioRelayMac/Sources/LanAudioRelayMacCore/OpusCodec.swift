import Copus
import Foundation

public final class OpusFrameEncoder {
    private let encoder: OpaquePointer

    public init() throws {
        var error: Int32 = 0
        guard let encoder = opus_encoder_create(
            Int32(AudioConstants.sampleRate),
            Int32(AudioConstants.channels),
            Int32(OPUS_APPLICATION_AUDIO),
            &error
        ) else {
            throw ProtocolError.opusError(error)
        }
        self.encoder = encoder
    }

    deinit {
        opus_encoder_destroy(encoder)
    }

    public func encode(_ pcm: [Int16]) throws -> Data {
        guard pcm.count == AudioConstants.pcmSamplesPerFrame else {
            throw ProtocolError.invalidPayloadLength
        }

        var mutablePcm = pcm
        var output = [UInt8](repeating: 0, count: 1275)
        let encodedBytes = mutablePcm.withUnsafeBufferPointer { pcmBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                opus_encode(
                    encoder,
                    pcmBuffer.baseAddress,
                    Int32(AudioConstants.samplesPerFrame),
                    outputBuffer.baseAddress,
                    Int32(output.count)
                )
            }
        }

        guard encodedBytes >= 0 else {
            throw ProtocolError.opusError(encodedBytes)
        }

        return Data(output.prefix(Int(encodedBytes)))
    }
}

public final class OpusFrameDecoder {
    private let decoder: OpaquePointer

    public init() throws {
        var error: Int32 = 0
        guard let decoder = opus_decoder_create(
            Int32(AudioConstants.sampleRate),
            Int32(AudioConstants.channels),
            &error
        ) else {
            throw ProtocolError.opusError(error)
        }
        self.decoder = decoder
    }

    deinit {
        opus_decoder_destroy(decoder)
    }

    public func decode(_ payload: Data) throws -> [Int16] {
        var mutablePayload = [UInt8](payload)
        var pcm = [Int16](repeating: 0, count: AudioConstants.pcmSamplesPerFrame)
        let decodedSamples = mutablePayload.withUnsafeBufferPointer { payloadBuffer in
            pcm.withUnsafeMutableBufferPointer { pcmBuffer in
                opus_decode(
                    decoder,
                    payloadBuffer.baseAddress,
                    Int32(payload.count),
                    pcmBuffer.baseAddress,
                    Int32(AudioConstants.samplesPerFrame),
                    0
                )
            }
        }

        guard decodedSamples >= 0 else {
            throw ProtocolError.opusError(decodedSamples)
        }

        return pcm
    }
}
