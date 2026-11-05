//
//  PassQRCodeView.swift
//  HackDifferent
//

import AudienceKit
import CoreImage.CIFilterBuiltins
import SwiftUI

struct PassQRCodeView: View {
    @Environment(AppModel.self) private var appModel
    @State var admission: Admission
    @State private var isRefunding = false
    @State private var refundError: String?

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pass Card
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text(admission.event?.name ?? admission.venue.name ?? "Hack Different Pass")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)

                        if let venueName = admission.venue.name {
                            Text(venueName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("Date: \(admission.night)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    // Rotating TOTP QR Code
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        let now = timeline.date
                        let code = appModel.client.coverPassCode(for: admission, at: now)
                        let remaining = CoverPass.secondsRemaining(at: now)

                        VStack(spacing: 14) {
                            if admission.status == .paid, let code, let qrImage = makeQRCodeImage(from: code) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white)
                                    )

                                VStack(spacing: 6) {
                                    ProgressView(
                                        value: Double(remaining),
                                        total: Double(CoverPass.windowLength)
                                    )
                                    .tint(.green)
                                    .frame(width: 200)

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text("Live pass • refreshes in \(remaining)s")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.secondary)
                                    Text("Pass Status: \(admission.status.rawValue)")
                                        .font(.subheadline.weight(.semibold))
                                    Text("QR code is active for paid passes.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 220, height: 220)
                            }
                        }
                    }

                    Divider()

                    // Pass Metadata
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Attendee")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(admission.profile.name)
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total Paid")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(admission.total.formattedAmount)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if admission.scanCount > 0 {
                        Label("Scanned \(admission.scanCount) time(s) at door", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)

                if admission.isRefundable {
                    Button(role: .destructive) {
                        Task { await refund() }
                    } label: {
                        if isRefunding {
                            ProgressView("Refunding pass…")
                        } else {
                            Label("Refund Pass", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefunding)
                }

                if let refundError {
                    Text(refundError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Admission Pass")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeQRCodeImage(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func refund() async {
        isRefunding = true
        refundError = nil
        defer { isRefunding = false }

        do {
            admission = try await appModel.api.refundAdmission(admissionID: admission.id)
            await appModel.refreshAdmissions()
        } catch let error as AudienceKitError {
            refundError = error.message
        } catch {
            refundError = error.localizedDescription
        }
    }
}
