// CoreMems/Views/PhotoMetadataSheetView.swift
import SwiftUI

struct PhotoMetadataSheetView: View {
  @ObservedObject var vm: SessionViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if vm.isLoadingMetadata {
          ProgressView("Loading details…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let metadata = vm.metadataForSheet {
          List {
            Section("Photo") {
              MetadataRow(label: "Date taken", value: metadata.formattedDate)
              MetadataRow(label: "Dimensions", value: metadata.formattedDimensions)
              MetadataRow(label: "File size", value: metadata.formattedFileSize)
              MetadataRow(label: "Format", value: metadata.formattedFormat)
              MetadataRow(label: "Filename", value: metadata.originalFilename)
              if metadata.isFavorite {
                MetadataRow(label: "Favorite", value: "❤️ Yes")
              }
            }

            if metadata.hasCameraInfo {
              Section("Camera") {
                MetadataRow(label: "Camera", value: metadata.formattedCamera)
                MetadataRow(label: "Lens", value: metadata.lensModel)
                MetadataRow(label: "Aperture", value: metadata.formattedAperture)
                MetadataRow(label: "Shutter speed", value: metadata.formattedShutterSpeed)
                MetadataRow(label: "ISO", value: metadata.formattedISO)
                MetadataRow(label: "Focal length", value: metadata.formattedFocalLength)
              }
            }

            if let mapsURL = metadata.mapsURL {
              Section("Location") {
                MetadataRow(label: "Coordinates", value: metadata.formattedCoordinate)
                Link("Open in Maps", destination: mapsURL)
              }
            }
          }
          .listStyle(.insetGrouped)
        } else {
          Text("No details available")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("Photo Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

private struct MetadataRow: View {
  let label: String
  let value: String?

  var body: some View {
    if let value, !value.isEmpty {
      HStack {
        Text(label).foregroundStyle(.secondary)
        Spacer()
        Text(value).multilineTextAlignment(.trailing)
      }
    }
  }
}
