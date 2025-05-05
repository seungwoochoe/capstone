//
//  AcknowledgementsView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-05-05.
//

import SwiftUI

struct AcknowledgementsView: View {
    
    @Binding var showingAbout: Bool
    
    private var licenseItems: [(header: String, content: String)] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "LICENSE", subdirectory: nil) else { return [] }
        
        return urls
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .map { url in
            let header = url.deletingPathExtension().lastPathComponent
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to load license text."
            return (header, content)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if licenseItems.isEmpty {
                    Text(verbatim: "No license files found in bundle.")
                } else {
                    VStack(alignment: .leading) {
                        Text(verbatim: "Portions of this software may utilize the following copyrighted material, the use of which is hereby acknowledged.")
                            .padding(.bottom)
                        
                        ForEach(licenseItems, id: \.header) { item in
                            Text(item.header)
                                .bold()
                                .padding(.bottom)
                            
                            Text(item.content.normalizedLicenseString())
                                .padding(.bottom)
                                .padding(.bottom)
                        }
                    }
                    .padding()
                }
            }
            .font(.callout)
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingAbout = false }
                        .font(.body).bold()
                }
            }
        }
    }
}

extension String {
    fileprivate func normalizedLicenseString() -> String {
        let paragraphs = self.components(separatedBy: "\n\n")
        let cleanedParagraphs = paragraphs.map { paragraph in
            paragraph.components(separatedBy: "\n").joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        return cleanedParagraphs.joined(separator: "\n\n")
    }
}

#Preview {
    AcknowledgementsView(showingAbout: .constant(true))
}
