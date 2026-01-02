//
//  AttachmentPickerView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit


// MARK: - Cross-Platform Image Helper

struct AttachmentImage {
    let data: Data

    #if os(macOS)
    var image: NSImage? {
        NSImage(data: data)
    }

    var swiftUIImage: Image {
        if let nsImage = image {
            return Image(nsImage: nsImage)
                .resizable()
        }
        return Image(systemName: "photo")
            .resizable()
    }
    #else
    var image: UIImage? {
        UIImage(data: data)
    }

    var swiftUIImage: Image {
        if let uiImage = image {
            return Image(uiImage: uiImage)
                .resizable()
        }
        return Image(systemName: "photo")
            .resizable()
    }
    #endif

    var hasValidImage: Bool {
        image != nil
    }
}

struct AttachmentPickerView: View {
    @Binding var attachments: [AttachmentData]
    var showAttachmentList: Bool = true
    @State private var showingFilePicker = false
    @State private var selectedAttachment: AttachmentData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showAttachmentList && !attachments.isEmpty {
                ForEach(attachments) { attachment in
                    AttachmentRow(attachment: attachment) {
                        selectedAttachment = attachment
                    } onDelete: {
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            
            Button {
                showingFilePicker = true
            } label: {
                Label("Add attachment", systemImage: "paperclip")
            }
            .buttonStyle(.bordered)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .plainText, .jpeg, .png],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $selectedAttachment) { attachment in
            AttachmentPreviewView(attachment: attachment)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let data = try Data(contentsOf: url)
                    let filename = url.lastPathComponent
                    let mimeType = mimeType(for: url)
                    
                    let attachment = AttachmentData(
                        filename: filename,
                        mimeType: mimeType,
                        data: data
                    )
                    attachments.append(attachment)
                } catch {
                    print("Error loading file: \(error)")
                }
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
    
    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}

// Temporary data structure for new attachments
struct AttachmentData: Identifiable {
    let id = UUID()
    let filename: String
    let mimeType: String
    let data: Data
    
    var fileExtension: String {
        let components = filename.components(separatedBy: ".")
        return components.last?.lowercased() ?? ""
    }
    
    var isImage: Bool {
        ["jpg", "jpeg", "png"].contains(fileExtension)
    }
    
    var isPDF: Bool {
        fileExtension == "pdf"
    }
    
    var iconName: String {
        if isImage {
            return "photo"
        } else if isPDF {
            return "doc.richtext"
        } else {
            return "doc.text"
        }
    }
}

struct AttachmentRow: View {
    let attachment: AttachmentData
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                Text(attachment.filename)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Remove", action: onDelete)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
        }
    }
}

struct AttachmentThumbnail: View {
    let attachment: AttachmentData
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    if attachment.isImage {
                        let attachmentImage = AttachmentImage(data: attachment.data)
                        if attachmentImage.hasValidImage {
                            attachmentImage.swiftUIImage
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            attachmentIconView
                        }
                    } else {
                        attachmentIconView
                    }
                    
                    Text(attachment.filename)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(maxWidth: 70)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, .red)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }
    
    private var attachmentIconView: some View {
        Image(systemName: attachment.iconName)
            .font(.title)
            .frame(width: 60, height: 60)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AttachmentPreviewView: View {
    let attachment: AttachmentData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if attachment.isImage {
                    let attachmentImage = AttachmentImage(data: attachment.data)
                    if attachmentImage.hasValidImage {
                        attachmentImage.swiftUIImage
                            .aspectRatio(contentMode: .fit)
                    } else {
                        previewUnavailableView
                    }
                } else if attachment.isPDF {
                    PDFPreviewView(data: attachment.data)
                } else if let text = String(data: attachment.data, encoding: .utf8) {
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    previewUnavailableView
                }
            }
            .navigationTitle(attachment.filename)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var previewUnavailableView: some View {
        ContentUnavailableView {
            Label("Preview unavailable", systemImage: "doc")
        }
    }
}

// MARK: - PDF Preview

#if os(macOS)
struct PDFPreviewView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}
#else
struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}
#endif

// View for existing attachments from database
struct ExistingAttachmentRow: View {
    let attachment: Attachment
    let onDelete: () -> Void
    @State private var showingPreview = false
    
    var body: some View {
        HStack {
            Button {
                showingPreview = true
            } label: {
                Text(attachment.filename)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Remove", action: onDelete)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPreview) {
            ExistingAttachmentPreviewView(attachment: attachment)
        }
    }
}

struct ExistingAttachmentView: View {
    let attachment: Attachment
    let onDelete: () -> Void
    @State private var showingPreview = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                showingPreview = true
            } label: {
                VStack(spacing: 4) {
                    if attachment.isImage {
                        let attachmentImage = AttachmentImage(data: attachment.data)
                        if attachmentImage.hasValidImage {
                            attachmentImage.swiftUIImage
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            attachmentIconView
                        }
                    } else {
                        attachmentIconView
                    }
                    
                    Text(attachment.filename)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(maxWidth: 70)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, .red)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .sheet(isPresented: $showingPreview) {
            ExistingAttachmentPreviewView(attachment: attachment)
        }
    }
    
    private var attachmentIconView: some View {
        Image(systemName: attachment.iconName)
            .font(.title)
            .frame(width: 60, height: 60)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ExistingAttachmentPreviewView: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if attachment.isImage {
                    let attachmentImage = AttachmentImage(data: attachment.data)
                    if attachmentImage.hasValidImage {
                        attachmentImage.swiftUIImage
                            .aspectRatio(contentMode: .fit)
                    } else {
                        previewUnavailableView
                    }
                } else if attachment.isPDF {
                    PDFPreviewView(data: attachment.data)
                } else if let text = String(data: attachment.data, encoding: .utf8) {
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    previewUnavailableView
                }
            }
            .navigationTitle(attachment.filename)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var previewUnavailableView: some View {
        ContentUnavailableView {
            Label("Preview unavailable", systemImage: "doc")
        }
    }
}
