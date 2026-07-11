//
//  AboutView.swift
//  Hana
//
//  Created by Haruka on 2026/7/9.
//

import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    
    var body: some View {
        List {
            Section {
                valueRow(title: "Version", value: version)
                valueRow(title: "Build", value: build)
            }
            .hanaSettingsRow()
            
            Section {
                ForEach(playbackLibraries) { item in
                    LicenseRow(item: item)
                }
            } header: {
                Text("Playback Libraries")
            } footer: {
                Text("FFmpeg and libVLC are separate native projects from their Swift package wrappers.")
            }
            .hanaSettingsRow()
            
            Section("App Dependencies") {
                ForEach(appDependencies) { item in
                    LicenseRow(item: item)
                }
            }
            .hanaSettingsRow()
            
            Section {
                ForEach(hoshiReaderDependencies) { item in
                    LicenseRow(item: item)
                }
            } header: {
                Text("HoshiReader")
            } footer: {
                Text("HoshiReader is used through the Hana SwiftPM package fork and includes its own nested libraries.")
            }
            .hanaSettingsRow()
            
            Section("HoshiReader Attributions") {
                ForEach(hoshiReaderAttributions) { item in
                    LicenseRow(item: item)
                }
            }
            .hanaSettingsRow()
            
            Section {
                ForEach(buildTools) { item in
                    LicenseRow(item: item)
                }
            } header: {
                Text("Build Tools")
            } footer: {
                Text("These packages are resolved by SwiftPM for macros, plugins, or package tooling and are not user-facing runtime features.")
            }
            .hanaSettingsRow()
        }
        .hanaSettingsScreen()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func valueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    private var playbackLibraries: [LicenseItem] {
        [
            LicenseItem(
                name: "SwiftVLC",
                license: "MIT",
                url: URL(string: "https://github.com/harflabs/SwiftVLC")!,
                links: [
                    .init(title: "Hana LGPL fork", url: URL(string: "https://github.com/harukawu/SwiftVLC/tree/lgpl")!),
                    .init(title: "libVLC", url: URL(string: "https://www.videolan.org/vlc/")!)
                ],
                note: "Swift wrapper around libVLC. Hana currently uses the upstream static package for testing and should use the dynamic LGPL fork for distribution.",
                text: LicenseText.mit(copyright: "Copyright (c) 2025 Omar Albeik")
            ),
            LicenseItem(
                name: "libVLC",
                license: "LGPL-2.1-or-later",
                url: URL(string: "https://www.videolan.org/vlc/")!,
                note: "Hana uses libVLC through SwiftVLC. Keep the shipped libVLC binary, license text, and matching source offer aligned for release builds."
            ),
            LicenseItem(
                name: "FFmpeg-iOS",
                license: "LGPL-2.1",
                url: URL(string: "https://github.com/harukawu/FFmpeg-iOS/tree/lgpl")!,
                links: [
                    .init(title: "Original wrapper", url: URL(string: "https://github.com/kewlbear/FFmpeg-iOS")!),
                    .init(title: "FFmpeg", url: URL(string: "https://ffmpeg.org/legal.html")!)
                ],
                note: "Fork of kewlbear/FFmpeg-iOS rebuilt for dynamically linked LGPL libraries."
            ),
            LicenseItem(
                name: "FFmpeg",
                license: "LGPL-2.1-or-later",
                url: URL(string: "https://ffmpeg.org/legal.html")!,
                note: "This software uses libraries from the FFmpeg project under the LGPLv2.1."
            ),
            LicenseItem(
                name: "FFmpeg-iOS-Support",
                license: "LGPL-2.1",
                url: URL(string: "https://github.com/kewlbear/FFmpeg-iOS-Support")!,
                note: "Support package used by FFmpeg-iOS for platform hooks and linked system frameworks."
            )
        ]
    }
    
    private var appDependencies: [LicenseItem] {
        [
            LicenseItem(
                name: "PersistedObservation",
                license: "MIT",
                url: URL(string: "https://github.com/harukawu/PersistedObservation")!,
                note: "Swift macro package written for Hana.",
                text: LicenseText.mit(copyright: "Copyright (c) 2026 Haruka")
            ),
            LicenseItem(
                name: "MarqueeText",
                license: "MIT",
                url: URL(string: "https://github.com/harflabs/MarqueeText")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2025 Harf Labs")
            ),
            LicenseItem(
                name: "SWXMLHash",
                license: "MIT",
                url: URL(string: "https://github.com/drmohundro/SWXMLHash")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2014 David Mohundro")
            )
        ]
    }
    
    private var hoshiReaderDependencies: [LicenseItem] {
        [
            LicenseItem(
                name: "HoshiReader",
                license: "GPL-3.0",
                url: URL(string: "https://github.com/harukawu/Hoshi-Reader/tree/hana-package")!,
                links: [
                    .init(title: "Original project", url: URL(string: "https://github.com/Manhhao/Hoshi-Reader")!)
                ],
                note: "Hana uses a SwiftPM package fork of Manhhao/Hoshi-Reader."
            ),
            LicenseItem(
                name: "hoshidicts",
                license: "GPL-3.0",
                url: URL(string: "https://github.com/Manhhao/hoshidicts")!
            ),
            LicenseItem(
                name: "EPUBKit",
                license: "MIT",
                url: URL(string: "https://github.com/witekbobrowski/EPUBKit")!,
                note: "Vendored by HoshiReader.",
                text: LicenseText.mit(copyright: "Copyright (c) 2022 Witek Bobrowski")
            ),
            LicenseItem(
                name: "AEXML",
                license: "MIT",
                url: URL(string: "https://github.com/tadija/AEXML")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2014-2024 Marko Tadic (https://markotadic.com)")
            ),
            LicenseItem(
                name: "ZIPFoundation",
                license: "MIT",
                url: URL(string: "https://github.com/weichsel/ZIPFoundation")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)")
            ),
            LicenseItem(
                name: "SwiftUI Introspect",
                license: "MIT",
                url: URL(string: "https://github.com/siteline/SwiftUI-Introspect")!,
                text: LicenseText.mit(copyright: "Copyright 2019 Timber Software")
            ),
            LicenseItem(
                name: "libdeflate",
                license: "MIT",
                url: URL(string: "https://github.com/ebiggers/libdeflate")!,
                text: LicenseText.mit(copyright: "Copyright 2016 Eric Biggers\nCopyright 2024 Google LLC")
            ),
            LicenseItem(
                name: "utf8proc",
                license: "MIT/Unicode",
                url: URL(string: "https://github.com/JuliaStrings/utf8proc")!,
                note: "Included by hoshidicts for Unicode processing. Its license file also covers derived Unicode data."
            ),
            LicenseItem(
                name: "utfcpp",
                license: "BSL-1.0",
                url: URL(string: "https://github.com/nemtrif/utfcpp")!,
                text: LicenseText.boost
            ),
            LicenseItem(
                name: "glaze",
                license: "MIT",
                url: URL(string: "https://github.com/stephenberry/glaze")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2019 - present, Stephen Berry")
            ),
            LicenseItem(
                name: "xxHash",
                license: "BSD-2-Clause",
                url: URL(string: "https://github.com/Cyan4973/xxHash")!,
                text: LicenseText.bsd2XXHash
            ),
            LicenseItem(
                name: "unordered_dense",
                license: "MIT",
                url: URL(string: "https://github.com/martinus/unordered_dense")!,
                text: LicenseText.mit(copyright: "Copyright (c) 2022 Martin Leitner-Ankerl")
            ),
            LicenseItem(
                name: "zstd",
                license: "BSD-3-Clause",
                url: URL(string: "https://github.com/facebook/zstd")!,
                text: LicenseText.bsd3Zstd
            ),
            LicenseItem(
                name: "kanji-processor",
                license: "MIT",
                url: URL(string: "https://github.com/yomidevs/kanji-processor")!,
                note: "Data embedded by hoshidicts for kanji variant normalization.",
                text: LicenseText.mit(copyright: "Copyright (c) 2024-2025 Lyroxide, Yomitan Authors")
            )
        ]
    }
    
    private var hoshiReaderAttributions: [LicenseItem] {
        [
            LicenseItem(
                name: "Ankiconnect Android",
                license: "GPL-3.0",
                url: URL(string: "https://github.com/KamWithK/AnkiconnectAndroid")!
            ),
            LicenseItem(
                name: "Yomitan",
                license: "GPL-3.0",
                url: URL(string: "https://github.com/yomidevs/yomitan")!
            ),
            LicenseItem(
                name: "ttu Reader",
                license: "BSD-3-Clause",
                url: URL(string: "https://github.com/ttu-ttu/ebook-reader")!
            ),
            LicenseItem(
                name: "JMdict for Yomitan",
                license: "CC-BY-SA-4.0",
                url: URL(string: "https://github.com/yomidevs/jmdict-yomitan")!
            ),
            LicenseItem(
                name: "Jiten",
                license: "Apache-2.0",
                url: URL(string: "https://github.com/Sirush/Jiten")!
            ),
            LicenseItem(
                name: "Kanji alive",
                license: "CC-BY-4.0",
                url: URL(string: "https://github.com/kanjialive/kanji-data-media")!
            ),
            LicenseItem(
                name: "Tofugu/WaniKani Audio",
                license: "CC-BY-SA-4.0",
                url: URL(string: "https://github.com/tofugu/japanese-vocabulary-pronunciation-audio")!
            )
        ]
    }
    
    private var buildTools: [LicenseItem] {
        [
            LicenseItem(
                name: "SwiftSyntax",
                license: "Apache-2.0",
                url: URL(string: "https://github.com/swiftlang/swift-syntax")!,
                note: "Used by PersistedObservation macro implementation."
            ),
            LicenseItem(
                name: "Swift Argument Parser",
                license: "Apache-2.0",
                url: URL(string: "https://github.com/apple/swift-argument-parser")!,
                note: "Resolved by FFmpeg-iOS for its command-line tool target."
            )
        ]
    }
}

private struct LicenseItem: Identifiable, Sendable {
    let name: String
    let license: String
    let url: URL
    var links: [LicenseLink] = []
    var note: String?
    var text: String?
    
    var id: String {
        name
    }
    
    var hasExpandedContent: Bool {
        note != nil || text != nil || !links.isEmpty
    }
}

private struct LicenseLink: Identifiable, Sendable {
    let title: String
    let url: URL
    
    var id: String {
        "\(title)-\(url.absoluteString)"
    }
}

private struct LicenseRow: View {
    let item: LicenseItem
    
    var body: some View {
        if item.hasExpandedContent {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Link("Project", destination: item.url)
                        .font(.caption)
                    
                    ForEach(item.links) { link in
                        Link(link.title, destination: link.url)
                            .font(.caption)
                    }
                    
                    if let note = item.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let text = item.text {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } label: {
                label
            }
        } else {
            Link(destination: item.url) {
                label
            }
        }
    }
    
    private var label: some View {
        HStack {
            Text(item.name)
            Spacer(minLength: 16)
            Text(item.license)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private enum LicenseText {
    static func mit(copyright: String) -> String {
        """
        MIT License
        
        \(copyright)
        
        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:
        
        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.
        
        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """
    }
    
    static let boost = """
    Boost Software License - Version 1.0 - August 17th, 2003
    
    Permission is hereby granted, free of charge, to any person or organization
    obtaining a copy of the software and accompanying documentation covered by
    this license (the "Software") to use, reproduce, display, distribute,
    execute, and transmit the Software, and to prepare derivative works of the
    Software, and to permit third-parties to whom the Software is furnished to
    do so, all subject to the following:
    
    The copyright notices in the Software and this entire statement, including
    the above license grant, this restriction and the following disclaimer,
    must be included in all copies of the Software, in whole or in part, and
    all derivative works of the Software, unless such copies or derivative
    works are solely in the form of machine-executable object code generated by
    a source language processor.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
    SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
    FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
    """
    
    static let bsd2XXHash = """
    xxHash Library
    Copyright (c) 2012-2021 Yann Collet
    All rights reserved.
    
    BSD 2-Clause License (https://www.opensource.org/licenses/bsd-license.php)
    
    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.
    
    * Redistributions in binary form must reproduce the above copyright notice, this
      list of conditions and the following disclaimer in the documentation and/or
      other materials provided with the distribution.
    
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
    ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    """
    
    static let bsd3Zstd = """
    BSD License
    
    For Zstandard software
    
    Copyright (c) Meta Platforms, Inc. and affiliates. All rights reserved.
    
    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:
    
     * Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer.
    
     * Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.
    
     * Neither the name Facebook, nor Meta, nor the names of its contributors may
       be used to endorse or promote products derived from this software without
       specific prior written permission.
    
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
    ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    """
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
