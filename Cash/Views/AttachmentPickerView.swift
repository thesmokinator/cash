//
//  AttachmentPickerView.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct AttachmentPickerView: View {
    @Binding var attachments: [AttachmentData]
    @State private var showingFilePicker = false
    @State private var selectedAttachment: AttachmentData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attachments) { attachment in
                            AttachmentThumbnail(attachment: attachment) {
                                selectedAttachment = attachment
                            } onDelete: {
                                attachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                }
            }
            
            Button {
                showingFilePicker = true
            } label: {
                Label("Add Attachment", systemImage: "paperclip")
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

struct AttachmentThumbnail: View {
    let attachment: AttachmentData
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: attachment.iconName)
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
}

struct AttachmentPreviewView: View {
    let attachment: AttachmentData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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
                    ContentUnavailableView {
                        Label("Preview Unavailable", systemImage: "doc")
                    }
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
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct PDFPreviewView: NSViewRepresentable {
    let data: Data
    
    func makeNSView(context: Context) -> PDFViewWrapper {
        PDFViewWrapper(data: data)
    }
    
    func updateNSView(_ nsView: PDFViewWrapper, context: Context) {}
}

import PDFKit

class PDFViewWrapper: NSView {
    init(data: Data) {
        super.init(frame: .zero)
        
        let pdfView = PDFView(frame: bounds)
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        addSubview(pdfView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// View for existing attachments from database
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
                    if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: attachment.iconName)
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
}

struct ExistingAttachmentPreviewView: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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
                    ContentUnavailableView {
                        Label("Preview Unavailable", systemImage: "doc")
                    }
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
        .frame(minWidth: 500, minHeight: 400)
    }
}
