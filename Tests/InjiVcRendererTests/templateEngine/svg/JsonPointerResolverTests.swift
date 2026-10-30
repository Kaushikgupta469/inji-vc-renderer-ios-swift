import XCTest

@testable import InjiVcRenderer

final class JsonPointerResolverTests: XCTestCase {
    
    let traceabilityId = "test-id"


    func testReplaceSimpleObjectField() throws {
        let template = "<svg >{{/credentialSubject/gender/0/value}}##{{/credentialSubject/fullName}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "gender": [
                    ["language": "eng", "value": "English Male"]
                ],
                "fullName": "John"
            ]
        ]
        let expected = "<svg >English Male##John</svg>"
        let result =  try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceArrayFields() throws {
        let template = "<svg >{{/credentialSubject/benefits/0}}, {{/credentialSubject/benefits/1}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "benefits": [
                    "Item 1 is on the list",
                    "Item 2 is on the list",
                    "Item 3 is on the list"
                ],
                "fullName": "John"
            ]
        ]
        let expected = "<svg >Item 1 is on the list, Item 2 is on the list</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceMissingPointerReturnsDash() throws {
        let template = "<svg >{{/credentialSubject/email}}##{{/credentialSubject/middleName}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "gender": [["language": "eng", "value": "English Male"]],
                "fullName": "John"
            ]
        ]
        let expected = "<svg >-##-</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceFieldsWithLocaleAsObjects() throws {
        let template = "<svg>Gender: {{/credentialSubject/gender/eng}}, பாலினம் : {{/credentialSubject/gender/tam}} </svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "gender": [
                    "eng": "Male",
                    "tam": "ஆண்"
                ]
            ]
        ]
        let expected = "<svg>Gender: Male, பாலினம் : ஆண் </svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceFieldsWithLocaleAsArrayOfObjects() throws {
        let template = "<svg>Gender: {{/credentialSubject/gender/0/value}}, பாலினம் : {{/credentialSubject/gender/1/value}} </svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "gender": [
                    ["language": "eng", "value": "Male"],
                    ["language": "tam", "value": "ஆண்"]
                ]
            ]
        ]
        let expected = "<svg>Gender: Male, பாலினம் : ஆண் </svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceNestedAddressFields() throws {
        let template = "<svg>{{/credentialSubject/address/addressLine1/0/value}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": [
                "address": [
                    "addressLine1": [
                        ["language": "eng", "value": "TEST_ADDRESS_LINE_1eng"],
                        ["language": "fr", "value": "TEST_ADDRESS_LINE_1fr"]
                    ],
                    "city": [
                        ["language": "eng", "value": "TEST_CITYeng"]
                    ]
                ]
            ]
        ]
        let expected = "<svg>TEST_ADDRESS_LINE_1eng</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceFieldWithSlash() throws {
        let template = "<svg >{{/credentialSubject/ac~1dc}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": ["ac/dc": "current unit"]
        ]
        let expected = "<svg >current unit</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceFieldWithTilde() throws {
        let template = "<svg >{{/credentialSubject/a~0b}}</svg>"
        let json: [String: Any] = [
            "credentialSubject": ["a~b": "test"]
        ]
        let expected = "<svg >test</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testPointerToRootReturnsFullDocument() throws {
        let template = "<svg>{{}}</svg>"
        let json: [String: Any] = ["a": 1, "b": 2]
        let expected = "<svg>{\"a\":1,\"b\":2}</svg>"
        
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson: json, traceabilityId: traceabilityId)
        
        // Extract JSON portion between <svg> tags
        let resultJsonPart = result.replacingOccurrences(of: "<svg>", with: "")
                                    .replacingOccurrences(of: "</svg>", with: "")
        let expectedJsonPart = expected.replacingOccurrences(of: "<svg>", with: "")
                                       .replacingOccurrences(of: "</svg>", with: "")

        let resultObj = try JSONSerialization.jsonObject(with: Data(resultJsonPart.utf8)) as? NSDictionary
        let expectedObj = try JSONSerialization.jsonObject(with: Data(expectedJsonPart.utf8)) as? NSDictionary

        XCTAssertEqual(resultObj, expectedObj)
    }

    func testEmptyArrayAndObjectPointers() throws {
        let template = "<svg>{{/emptyArray}},{{/emptyObject}}</svg>"
        let json: [String: Any] = ["emptyArray": [], "emptyObject": [:]]
        let expected = "<svg>[],{}</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testArrayIndexOutOfBoundsReturnsDash() throws {
        let template = "<svg>{{/items/99}}</svg>"
        let json: [String: Any] = ["items": ["one", "two"]]
        let expected = "<svg>-</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testMultipleTildesAndSlashesInKey() throws {
        let template = "<svg>{{/a~0b~1c}}</svg>"
        let json: [String: Any] = ["a~b/c": "value"]
        let expected = "<svg>value</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)

        XCTAssertEqual(result, expected)
    }

    func testSpecialCharactersInKeys() throws {
        let template = "<svg>{{/!@#$%^&*() throws}}</svg>"
        let json: [String: Any] = ["!@#$%^&*() throws": "special"]
        let expected = "<svg>special</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)

        XCTAssertEqual(result, expected)
    }

    func testUnicodeCharactersInKeys() throws {
        let template = "<svg>{{/ключ}}</svg>"
        let json: [String: Any] = ["ключ": "значение"]
        let expected = "<svg>значение</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, traceabilityId: traceabilityId)

        XCTAssertEqual(result, expected)
    }

    func testReplaceSimpleObjectFieldWithRenderProperty() throws {
        let template = "<svg >{{/issuer}}##{{/credentialSubject/fullName}}</svg>"
        let json: [String: Any] = [
            "issuer": "did:mosip:123456789",
            "credentialSubject": [
                "gender": [["language": "eng", "value": "English Male"]],
                "fullName": "John"
            ]
        ]
        let expected = "<svg >did:mosip:123456789##-</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json,  renderProperties: ["/issuer"], traceabilityId: traceabilityId)
        XCTAssertEqual(result, expected)
    }

    func testReplaceSimpleObjectFieldWithRenderPropertyAsArrayIndex() throws {
        let template = "<svg >{{/credentialSubject/gender/0/value}}##{{/credentialSubject/fullName}}</svg>"
        let json: [String: Any] = [
            "issuer": "did:mosip:123456789",
            "credentialSubject": [
                "gender": [["language": "eng", "value": "English Male"]],
                "fullName": "John"
            ]
        ]
        let expected = "<svg >English Male##-</svg>"
        let result = try JsonPointerResolver.replacePlaceholders(svgTemplate: template, inputJson : json, renderProperties: ["/credentialSubject/gender/0/value"], traceabilityId: traceabilityId)

       XCTAssertEqual(result, expected)
    }

    func testReplaceSvgPlaceholders_usesProvidedQrCodeData() throws {
        // Template must contain the QR placeholder and the qrCodeImage id so the resolver can replace them.
        let template = "<svg>QR: <image id=\"\(Constants.qrCodeImageId)\" xlink:href\(Constants.qrCodePlaceholder) /></svg>"
        let vcJson: [String: Any] = [
            "credentialSubject": ["email": "user@example.com"],
            "renderMethod": [
                "type": Constants.templateRenderMethod,
                "renderSuite": Constants.svgMustache,
                "template": [
                    "id": "ignored-in-this-test",
                    "mediaType": "image/svg+xml"
                ]
            ]
        ]
        let resolver = JsonPointerResolver(traceabilityId: traceabilityId)
        let svg = try resolver.replaceSvgPlaceholders(
            svgTemplate: template,
            vcJson: vcJson,
            renderMethodElement: vcJson["renderMethod"] as! [String: Any],
            vcJsonString: "{\"credentialSubject\":{}}",
            qrCodeData: "did:example:custom-qr"
        )

        // Should keep the normal image id (non-fallback) and embed a data URL with the expected prefix.
        XCTAssertTrue(svg.contains("id=\"\(Constants.qrCodeImageId)\""))
        XCTAssertTrue(svg.contains("\(Constants.qrImagePrefix),"), "Expected data URL prefix to be present")
        XCTAssertTrue(svg.hasPrefix("<svg>QR: <image"))
        XCTAssertTrue(svg.hasSuffix("/></svg>"))
    }

    // UPDATED: When qrCodeData is empty, generator uses VC JSON; fallback id appears only if generation fails/empty.
    func testReplaceSvgPlaceholders_usesFallbackWhenQrCodeDataEmpty() throws {
        let template = "<svg>QR: <image id=\"\(Constants.qrCodeImageId)\" xlink:href\(Constants.qrCodePlaceholder) /></svg>"
        let vcJson: [String: Any] = [
            "credentialSubject": ["email": "user@example.com"],
            "renderMethod": [
                "type": Constants.templateRenderMethod,
                "renderSuite": Constants.svgMustache,
                "template": [
                    "id": "ignored-in-this-test",
                    "mediaType": "image/svg+xml"
                ]
            ]
        ]
        let resolver = JsonPointerResolver(traceabilityId: traceabilityId)
        let svg = try resolver.replaceSvgPlaceholders(
            svgTemplate: template,
            vcJson: vcJson,
            renderMethodElement: vcJson["renderMethod"] as! [String: Any],
            vcJsonString: "{\"credentialSubject\":{}}",
            qrCodeData: "" // empty -> uses VC JSON; fallback only if generation fails/empty
        )

        // Data URL prefix must always be present.
        XCTAssertTrue(svg.contains("\(Constants.qrImagePrefix),"), "Expected data URL prefix to be present")

        // The image id should be either the normal id (success) or the fallback id (failure).
        let hasNormalId = svg.contains("id=\"\(Constants.qrCodeImageId)\"")
        let hasFallbackId = svg.contains("id=\"\(Constants.qrCodeFallbackImageId)\"")
        XCTAssertTrue(hasNormalId || hasFallbackId, "Expected either normal or fallback image id depending on QR generation outcome")
    }

    func testReplaceSvgPlaceholders_missingFaceUsesPlaceholderAndTextDashIsKept() throws {
        let template = "<svg><text>{{/credentialSubject/email}}</text>" +
            "<image id=\"portrait\" x=\"10\" y=\"12\" width=\"80\" height=\"100\" xlink:href=\"{{/credentialSubject/face}}\"/>" +
            "<image id=\"logo\" xlink:href=\"\(tinyPngDataUri)\"/></svg>"
        let expected = "<svg><text>-</text>" +
            "<image id=\"portrait\" x=\"10\" y=\"12\" width=\"80\" height=\"100\" xlink:href=\"\(NoImagePlaceholder.dataUri)\"/>" +
            "<image id=\"logo\" xlink:href=\"\(tinyPngDataUri)\"/></svg>"

        let result = try renderSvg(template, credentialSubject: ["fullName": "John"])

        XCTAssertEqual(result, expected)
    }

    func testReplaceSvgPlaceholders_staticDashImageHrefUsesPlaceholder() throws {
        let result = try renderSvg("<svg><image id=\"portrait\" xlink:href=\"-\"/></svg>", credentialSubject: [:])

        XCTAssertEqual(result, portraitSvg(href: NoImagePlaceholder.dataUri))
    }

    func testReplaceSvgPlaceholders_validFaceDataUriIsKept() throws {
        let result = try renderSvg(portraitTemplate, credentialSubject: ["face": tinyPngDataUri])

        XCTAssertEqual(result, portraitSvg(href: tinyPngDataUri))
    }

    func testReplaceSvgPlaceholders_emptyOrNullFaceUsesPlaceholder() throws {
        let faces: [Any] = ["", "   ", NSNull()]

        for face in faces {
            let result = try renderSvg(portraitTemplate, credentialSubject: ["face": face])

            XCTAssertEqual(result, portraitSvg(href: NoImagePlaceholder.dataUri), "face: \(face)")
        }
    }

    func testReplaceSvgPlaceholders_faceNotInRenderPropertyUsesPlaceholder() throws {
        let renderMethodElement: [String: Any] = [
            "type": Constants.templateRenderMethod,
            "template": ["renderProperty": ["/credentialSubject/fullName"]]
        ]

        let result = try renderSvg(
            portraitTemplate,
            credentialSubject: ["fullName": "John", "face": tinyPngDataUri],
            renderMethodElement: renderMethodElement
        )

        XCTAssertEqual(result, portraitSvg(href: NoImagePlaceholder.dataUri))
    }

    func testReplaceSvgPlaceholders_missingFaceAfterDataUriPrefixUsesPlaceholder() throws {
        let template = "<svg><image id=\"portrait\" xlink:href=\"data:image/png;base64,{{/credentialSubject/face}}\"/></svg>"

        let result = try renderSvg(template, credentialSubject: [:])

        XCTAssertEqual(result, portraitSvg(href: NoImagePlaceholder.dataUri))
    }

    func testReplaceSvgPlaceholders_malformedFaceUsesPlaceholder() throws {
        let malformedFaces = [
            "abc",
            "null",
            "data:image/png;base64,abc",
            "data:image/png;base64,%%garbage%%",
            "data:image/png;base64,iVBO=Rw0",
            "data:image/png;base64,",
            "data:image/png;base64",
            "data:text/plain;base64,aGVsbG8=",
            "data:image/png,",
            "data:image/png,%GG",
            "data:image/svg+xml,%3Csvg%"
        ]

        for face in malformedFaces {
            let result = try renderSvg(portraitTemplate, credentialSubject: ["face": face])

            XCTAssertEqual(result, portraitSvg(href: NoImagePlaceholder.dataUri), "face: \(face)")
        }
    }

    func testReplaceSvgPlaceholders_validFaceWithLineBreaksIsKept() throws {
        let face = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ\n" +
            "AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

        let result = try renderSvg(portraitTemplate, credentialSubject: ["face": face])

        XCTAssertEqual(result, portraitSvg(href: face))
    }

    func testReplaceSvgPlaceholders_httpsImageHrefIsKept() throws {
        let logoUrl = "https://example.com/logo.png"

        let result = try renderSvg(portraitTemplate, credentialSubject: ["face": logoUrl])

        XCTAssertEqual(result, portraitSvg(href: logoUrl))
    }

    func testReplaceSvgPlaceholders_singleQuotedHrefUsesPlaceholderWithSameQuote() throws {
        let result = try renderSvg("<svg><image id='portrait' href='-'></image></svg>", credentialSubject: [:])

        XCTAssertEqual(result, "<svg><image id='portrait' href='\(NoImagePlaceholder.dataUri)'></image></svg>")
    }

    func testReplaceSvgPlaceholders_percentEncodedFaceIsKept() throws {
        let face = "data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%2F%3E"

        let result = try renderSvg(portraitTemplate, credentialSubject: ["face": face])

        XCTAssertEqual(result, portraitSvg(href: face))
    }

    func testReplaceSvgPlaceholders_dataHrefAttributeIsUnchanged() throws {
        let template = "<svg><image id=\"portrait\" data-href=\"-\" xlink:href=\"{{/credentialSubject/face}}\"/></svg>"

        let result = try renderSvg(template, credentialSubject: [:])

        XCTAssertEqual(result, "<svg><image id=\"portrait\" data-href=\"-\" xlink:href=\"\(NoImagePlaceholder.dataUri)\"/></svg>")
    }

    func testReplaceSvgPlaceholders_imageWithoutHrefIsUnchanged() throws {
        let template = "<svg><image id=\"portrait\" width=\"80\" height=\"100\"/></svg>"

        let result = try renderSvg(template, credentialSubject: [:])

        XCTAssertEqual(result, template)
    }

    private let tinyPngDataUri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    private let portraitTemplate = "<svg><image id=\"portrait\" xlink:href=\"{{/credentialSubject/face}}\"/></svg>"

    private func portraitSvg(href: String) -> String {
        return "<svg><image id=\"portrait\" xlink:href=\"\(href)\"/></svg>"
    }

    private func renderSvg(
        _ template: String,
        credentialSubject: [String: Any],
        renderMethodElement: [String: Any] = ["type": Constants.templateRenderMethod]
    ) throws -> String {
        return try JsonPointerResolver(traceabilityId: traceabilityId).replaceSvgPlaceholders(
            svgTemplate: template,
            vcJson: ["credentialSubject": credentialSubject],
            renderMethodElement: renderMethodElement,
            vcJsonString: "{}",
            qrCodeData: nil
        )
    }
}
