//
//  AboutView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI

struct AboutView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var showAcknowledgements: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .foregroundStyle(.gray)
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                    
                    Text(SCApp.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version \(SCApp.version)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Acknowledgements") {
                        showAcknowledgements = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .padding(.top, -60)
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationDestination(isPresented: $showAcknowledgements) {
                AcknowledgementsView()
                    .navigationTitle("Acknowledgements")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

// MARK: - AcknowledgementsView

struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var licenseItems: [(header: String, content: String)] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "LICENSE", subdirectory: nil) else { return [] }
        
        return urls.map { url in
            let header = url.deletingPathExtension().lastPathComponent
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to load license text."
            return (header, content)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if licenseItems.isEmpty {
                    Text("No license files found in bundle.")
                } else {
                    VStack(alignment: .leading) {
                        Text("Portions of this software may utilize the following copyrighted material, the use of which is hereby acknowledged.")
                            .padding(.bottom)
                        
                        ForEach(licenseItems, id: \.header) { item in
                            Text(item.header)
                                .bold()
                                .padding(.bottom)
                            
                            Text(item.content.normalizedLicenseString())
                                .padding(.bottom)
                        }
                    }
                    .padding()
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

// MARK: - Preview

#Preview {
    //    AcknowledgementsView()
    AboutView()
}
