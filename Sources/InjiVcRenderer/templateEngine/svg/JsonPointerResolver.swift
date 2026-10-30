import Foundation

enum JsonPointerError: Error {
    case invalidPointer
    case notFound
    case typeMismatch
}

final class JsonPointerResolver {
    private let traceabilityId: String

    private static let placeholderRegex = try! NSRegularExpression(
        pattern: #"\{\{(/[^}]*)\}\}|\{\{\}\}"#
    )
    private static let imageTagRegex = try! NSRegularExpression(
        pattern: #"<(?:[\w.-]+:)?image\b[^>]*/>|<(?:[\w.-]+:)?image\b[^>]*>\s*</(?:[\w.-]+:)?image>"#,
        options: [.caseInsensitive]
    )
    private static let hrefAttributeRegex = try! NSRegularExpression(
        pattern: #"(?<![\w.:-])((?:[\w.-]+:)?)href\s*=\s*(["'])(.*?)\2"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let malformedPercentEscapeRegex = try! NSRegularExpression(
        pattern: "%(?![0-9A-Fa-f]{2})"
    )
    public static let className = String(describing: JsonPointerResolver.self)
    private let qrCodeGenerator: QrCodeGeneratorProtocol = QrCodeGenerator() as QrCodeGeneratorProtocol

    
    init(traceabilityId: String) {
        self.traceabilityId = traceabilityId
    }



    private static func toReplaceMentString(_ value: Any?) -> String {
        switch value {
        case nil:
            return "-"
        case let v as String:
            return v
        case let v as NSNumber:
            return v.stringValue
        case let v as [Any]:
            return jsonString(from: v) ?? "\(v)"
        case let v as [String: Any]:
            return jsonString(from: v) ?? "\(v)"
        default:
            return "-"
        }
    }
    
    /// Replaces placeholders in an SVG template using a Verifiable Credential JSON.
    /// Supports optional whitelist of allowed placeholders.
    static func replacePlaceholders(svgTemplate: String,
                                    inputJson: Any,
                                    renderProperties: [String]? = nil,
                                    traceabilityId: String
    ) throws -> String {
        let nsRange = NSRange(svgTemplate.startIndex..<svgTemplate.endIndex,
                              in: svgTemplate)
        var result = svgTemplate
        let matches = placeholderRegex.matches(in: svgTemplate,
                                               range: nsRange).reversed()

        for match in matches {
            let range = match.range(at: 1)
            let pointerPath: String
            if let r = Range(range, in: svgTemplate) {
                pointerPath = String(svgTemplate[r])
            } else {
                pointerPath = ""
            }

            if let props = renderProperties, !props.contains(pointerPath) {
                result.replaceSubrange(Range(match.range, in: result)!, with: "-")
                continue
            }

            let value: Any?
            if pointerPath.isEmpty {
                value = inputJson
            } else {
                do {
                        value = try resolvePointer(root: inputJson, pointer: pointerPath)
                    } catch JsonPointerError.notFound {
                        print("ERROR [\(VcRendererErrorCodes.missingJsonPath)] - Missing: \(pointerPath) | Class: \(className) | TraceabilityId: \(traceabilityId)")
                        value = nil
                    } catch let error {
                        print("ERROR while resolving pointer \(pointerPath): \(error) | Class: \(className) | TraceabilityId: \(traceabilityId)")
                        value = nil
                    }
            }

            let replacement: String = toReplaceMentString(value)

            result.replaceSubrange(Range(match.range, in: result)!, with: replacement)
        }

        return result
    }

    /// Strict RFC 6901 JSON Pointer resolution
    static func resolvePointer(root: Any, pointer: String) throws -> Any {
        if pointer.isEmpty {
            return root
        }
        guard pointer.first == "/" else { throw JsonPointerError.invalidPointer }

        let tokens = pointer.dropFirst().split(separator: "/").map {
            $0.replacingOccurrences(of: "~1", with: "/")
              .replacingOccurrences(of: "~0", with: "~")
        }

        var current: Any = root
        for token in tokens {
            if let dict = current as? [String: Any] {
                guard let next = dict[token] else { throw JsonPointerError.notFound }
                current = next
            } else if let arr = current as? [Any],
                      let idx = Int(token), idx >= 0, idx < arr.count {
                current = arr[idx]
            } else {
                throw JsonPointerError.typeMismatch
            }
        }
        return current
    }

    private static func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        if let data = try? JSONSerialization.data(withJSONObject: value,
                                                  options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
    
    func replaceSvgPlaceholders(
        svgTemplate: String,
        vcJson: [String: Any],
        renderMethodElement: [String: Any],
        vcJsonString: String,
        qrCodeData: String?
    ) throws -> String {
        let svgWithQrCodeReplaced = replaceQrCodePlaceholder(svgTemplate: svgTemplate, vcJsonString: vcJsonString, qrCodeData: qrCodeData)
        let svgWithValues = try replaceVcPlaceholders(svgTemplate: svgWithQrCodeReplaced, vcJson: vcJson, element: renderMethodElement)
        return JsonPointerResolver.replaceInvalidImageHrefs(svgTemplate: svgWithValues)
    }
    
    private func replaceVcPlaceholders(svgTemplate: String, vcJson: [String: Any], element: [String: Any])throws -> String {
        var renderProperties: [String]? = nil
                if let template = element[Constants.template] as? [String: Any],
                   let renderProperty = template[Constants.renderProperty] as? [String] {
                    renderProperties = renderProperty
                }
        return  try JsonPointerResolver.replacePlaceholders(
             svgTemplate: svgTemplate,
             inputJson: vcJson,
            renderProperties: renderProperties,
            traceabilityId: traceabilityId
        )

    }
    
    private func replaceQrCodePlaceholder(
        svgTemplate: String,
            vcJsonString: String,
        qrCodeData: String?
        ) -> String {
            guard svgTemplate.contains(Constants.qrCodePlaceholder) else {
                return svgTemplate
            }
        

            let qrBase64: String?
            do {
                if let qrData = qrCodeData, !qrData.isEmpty {
                        qrBase64 = try qrCodeGenerator.generateFromQrData(
                            qrData: qrData,
                            traceabilityId: traceabilityId
                        )
                    } else {
                    qrBase64 = try qrCodeGenerator.generateFromVcJson(
                        vcJson: vcJsonString,
                        traceabilityId: traceabilityId
                    )
                }
            } catch {
                qrBase64 = nil
            }

            let (finalQrBase64, imageId): (String, String) = {
                if let qr = qrBase64, !qr.isEmpty {
                    return (qr, Constants.qrCodeImageId)
                } else {
                    return (Constants.fallbackQrCode, Constants.qrCodeFallbackImageId)
                }
            }()

            let qrImageTag = "\(Constants.qrImagePrefix),\(finalQrBase64)"

            return svgTemplate
                .replacingOccurrences(of: Constants.qrCodePlaceholder, with: qrImageTag)
                .replacingOccurrences(of: Constants.qrCodeImageId, with: imageId)
        }

    private static func replaceInvalidImageHrefs(svgTemplate: String) -> String {
        var result = svgTemplate
        let imageMatches = imageTagRegex.matches(
            in: svgTemplate,
            range: NSRange(svgTemplate.startIndex..<svgTemplate.endIndex, in: svgTemplate)
        ).reversed()

        for imageMatch in imageMatches {
            guard let imageRange = Range(imageMatch.range, in: result) else { continue }
            result.replaceSubrange(imageRange, with: replaceInvalidHrefs(imageTag: String(result[imageRange])))
        }
        return result
    }

    private static func replaceInvalidHrefs(imageTag: String) -> String {
        var result = imageTag
        let hrefMatches = hrefAttributeRegex.matches(
            in: imageTag,
            range: NSRange(imageTag.startIndex..<imageTag.endIndex, in: imageTag)
        ).reversed()

        for hrefMatch in hrefMatches {
            guard let hrefRange = Range(hrefMatch.range, in: result),
                  let prefixRange = Range(hrefMatch.range(at: 1), in: imageTag),
                  let quoteRange = Range(hrefMatch.range(at: 2), in: imageTag),
                  let valueRange = Range(hrefMatch.range(at: 3), in: imageTag),
                  !isRenderableImageHref(String(imageTag[valueRange])) else {
                continue
            }
            let quote = imageTag[quoteRange]
            result.replaceSubrange(hrefRange, with: "\(imageTag[prefixRange])href=\(quote)\(NoImagePlaceholder.dataUri)\(quote)")
        }
        return result
    }

    private static func isRenderableImageHref(_ href: String) -> Bool {
        let value = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasPrefixIgnoringCase(value, "http://") || hasPrefixIgnoringCase(value, "https://") {
            return true
        }
        return hasPrefixIgnoringCase(value, "data:") && isValidImageDataUri(value)
    }

    private static func isValidImageDataUri(_ dataUri: String) -> Bool {
        let content = dataUri.dropFirst("data:".count)
        guard let commaIndex = content.firstIndex(of: ",") else { return false }

        let metadata = content[..<commaIndex]
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard let mediaType = metadata.first, mediaType.hasPrefix("image/") else { return false }

        let payload = String(content[content.index(after: commaIndex)...]).filter { !$0.isWhitespace }
        return metadata.dropFirst().contains("base64") ? isBase64(payload) : isPercentEncoded(payload)
    }

    private static func isPercentEncoded(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return !value.isEmpty && malformedPercentEscapeRegex.firstMatch(in: value, range: range) == nil
    }

    private static func isBase64(_ value: String) -> Bool {
        let paddingCount = value.reversed().prefix(while: { $0 == "=" }).count
        return !value.isEmpty
            && value.count % 4 == 0
            && paddingCount <= 2
            && value.dropLast(paddingCount).allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "+" || $0 == "/") }
    }

    private static func hasPrefixIgnoringCase(_ value: String, _ prefix: String) -> Bool {
        return value.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil
    }
}
