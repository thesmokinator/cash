//
//  Attachment.swift
//  Cash
//
//  Created by Michele Broggi on 26/11/25.
//

import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID
    var filename: String
    var mimeType: String
    var data: Data
    var createdAt: Date
    
    var transaction: Transaction?
    
    var fileExtension: String {
        let components = filename.components(separatedBy: ".")
        return components.last?.lowercased() ?? ""
    }
    
    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic"].contains(fileExtension)
    }
    
    var isPDF: Bool {
        fileExtension == "pdf"
    }
    
    var isText: Bool {
        fileExtension == "txt"
    }
    
    var iconName: String {
        if isImage {
            return "photo"
        } else if isPDF {
            return "doc.richtext"
        } else if isText {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    init(filename: String, mimeType: String, data: Data) {
        self.id = UUID()
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.createdAt = Date()
    }
}
