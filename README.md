## InjiVcRenderer - Swift Library
- A Swift library to convert SVG Template to SVG Image by replacing the placeholders in the SVG Template with actual Verifiable Credential Json Data. Strictly follows JSON Pointer Algorithm RFC6901 to extract the values from the VC.

## Installation
To include InjiVcRenderer in your Swift project:

- Create a new Swift project.
- Add package dependency: Enter Package URL of InjiVcRenderer repo

### API
- `generateCredentialDisplayContent(credentialFormat: CredentialFormat, wellKnownJson: String? = nil, vcJsonString: String, qrCodeData: String? = nil): [Any]` - expects the Verifiable Credential as parameter and returns the replaced SVG Template.
    - `vcJsonString` - VC Downloaded in stringified format.
    - `wellKnownJson` - Well-known Json downloaded in stringified format. It is optional parameter.
    - `credentialFormat` - Enum to specify the credential format. Currently only LDP_VC format is supported.
    - `qrCodeData` (optional) - Custom data used to generate the QR code.
       -  If provided → QR code is generated using this value.
       -  If not provided or empty → entire VC JSON string is used as fallback.
#### Custom QR Code Data Support
    - The API supports passing custom data for QR code generation via `qrCodeData`.
    - If `qrCodeData` is provided, it will be used to generate the QR code.
    - If `qrCodeData` is not provided or empty, the full Verifiable Credential JSON will be used as fallback.
    NOTE : It is preferred that qrCodeData provided to the method is already encoded (for example, Base45-encoded).
       
- This method takes entire VC data as input.
- Example :
```
        let vcJson = """{
            "credentialSubject": {
                "fullName": "John",
                "gender": [
                    "language": "eng",
                    "value": "Male"
                ] 
            },
            "renderMethod": {
                    "type": "TemplateRenderMethod",
                    "renderSuite": "svg-mustache",
                      "template": {
                        "id": "https://degree.example/credential-templates/sample.svg",
                        "mediaType": "image/svg+xml",
                        "digestMultibase": "zQmerWC85Wg6wFl9znFCwYxApG270iEu5h6JqWAPdhyxz2dR"
                      }
                  }
              }
        }"""
        // Assume SVG Template hosted is "<svg>{{/credentialSubject/gender}}##{{/credentialSubject/fullName}}</svg>"
    Result will be => [<svg>Male##John</svg>]
```
- Returns the Replaced svg template to render proper SVG Image. It returns the list of SVG Template if multiple render methods are present in the VC.
- If the `href` or `xlink:href` value of an `<image>` cannot be drawn (`-` from a missing value, an empty value or a malformed data URI), it is replaced with an embedded "No Image Available" placeholder. Valid image data URIs and http(s) URLs are left unchanged. An `<image>` without an href attribute is not changed.

## Package Structure

```
Sources
├── InjiVcRenderer.swift              # Main library class with public API
├── constants/         # Constants used across the library
│   ├── Constants.swift   
│   ├── ContentType.swift   
│   ├── CredentialFormat.swift   
│   ├── NetworkConstants.swift      
│   └── VcRendererErrorCodes.swift #Error codes used for Custom Exceptions              
│   
├── exceptions/        # Exceptions
│   ├── VcRendererExceptions.swift  # Centralized exception definitions
│   
│── qrCode/          
│   │   ├── QRCodeGenerator.swift  # QR code generation utility
│── templateEngine/svg/        # Json Pointer Algorithm implementation
    |--JsonPointerResolver.swift    
    |--NoImagePlaceholder.swift  # Fallback portrait for missing or invalid image hrefs
├── utils      # Utility classes    
│   ├── TemplateHelper.swift      
│   └── XMLHelper.swift
├── networkManager      
|   ├── NetworkManager.kt       # Network related utilities
|   ├── TemplateResponse.kt      
```

###### Exceptions

1. InvalidRenderSuiteException is thrown if render suite is not `svg-mustache`
2. InvalidRenderMethodTypeException is thrown if render method type is not `TemplateRenderMethod`
3. QRCodeGenerationFailureException is thrown if QR code generation fails and fallback QR is also unavailable
4. MissingTemplateIdException is thrown if template id is missing in render method
5. SvgFetchException is thrown if fetching SVG from the URL fails
6. InvalidRenderMethodException is thrown if render method object is invalid
7. MultibaseValidationException is thrown if digestMultibase validation fails



### Steps involved in SVG Template to SVG Image Conversion
- Render Method Extraction from VC
  - Extracts the render method from the VC Json data.
  - If multiple render methods are present, it will process all the render methods and return the list of replaced SVG Templates.


#### Downloading SVG Template from URL in VC
  - If Render Method object has `template` field as object with `id` field as url and `mediaType` as `image/svg+xml`, SVG Template needs to be downloaded from the URL and then replace the placeholders.
      ```
          "renderMethod": {
          "type": "TemplateRenderMethod",
          "renderSuite": "svg-mustache",
          "template": {
                  "id": "https://degree.example/credential-templates/bachelors",
                  "mediaType": "image/svg+xml",
                  "digestMultibase": "zQmerWC85Wg6wFl9znFCwYxApG270iEu5h6JqWAPdhyxz2dR"
              }
          }
      ```
  - Render method type should be `TemplateRenderMethod` and render suite should be `svg-mustache`.
  - Note : Embedded SVG Template and hosting render method as jsonld document are not supported in this library. Hosting the SVG Template as URL is supported.


#### Preprocessing the SVG Template

##### QR Code Placeholder
  - If the SVG Template has `{{/qrCodeImage}}` placeholder:
    - QR code is generated using `qrCodeData` if provided.
    - Otherwise, QR code is generated using the entire VC JSON string.
    - Example:
        ```
        let vcJson = {"credentialSubject" : "id": "did:example:123456789", "name": "Tester"}
        
        let svgTempalte = "<svg>{{/qrCodeImage}}</svg>"
        
        //result => <svg><image id = "qrCodeImage" href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAADICAYAAACtWK6eAAAABmJLR0QA/wD/AP+gvaeTAAAIKklEQVR4nO3de5QdZZnv8e9M7MzMzM7szszM7s"
        ```
- Note: It is mandatory to have `id` field in the `<image>` as `qrCodeImage` and placeholder as `{{/qrCodeImage}}` to generate the QR code.  Because if it is fallback scenario, `<image>` id will be replaced with `qrCodeFallbackImage` which can be used to identify from consumer side if design have valid QR code or fallback one.

##### Custom QR Code Data Support (NEW)
      ````
           let renderer = InjiVcRenderer(traceabilityId: "trace-123")
           let result = try renderer.generateCredentialDisplayContent(
                 credentialFormat: .ldp_vc,
                 vcJsonString: vcJson,
                 qrCodeData: "did:example:123456789"
           )
      ````


➡ QR code encodes did:example:123456789 instead of full VC JSON.
##### Handling Render Property
  - If the `template` field is an object and has `renderMethod` property. Property in the `renderMethod` will be taken into consideration for further processing and rest of the fields placeholders will be replaced with empty string.
    - Example:
        ```
          "renderMethod": {
              "type": "TemplateRenderMethod",
              "renderSuite": "svg-mustache",
              "template": {
                      "id": "https://example.edu/credential-templates/BachelorDegree",
                      "mediaType": "image/svg+xml",
                      "digestMultibase": "zQmerWC85Wg6wFl9znFCwYxApG270iEu5h6JqWAPdhyxz2dR",
                      "renderProperty": [
                        "/issuer", "/validFrom", "/credentialSubject/degree/name"
                      ]
                  }
          }
        ```
    - In the above example, only the fields `issuer`, `validFrom` and `credentialSubject/degree/name` will be considered for replacing the placeholders in the SVG Template.
  - If `renderProperty` is not present, all the fields in the VC will be considered for replacing the placeholders in the SVG Template.

##### Array Fields Handling
- For array fields in the VC, index based approach will be followed.
- Example:
    ```
    let vcJson = {"credentialSubject" : "benefits": ["Critical Surgery", "Full Health Checkup", "Testing"]}
    
    let svgTempalte = "<svg>{{/benefits}}</svg>"
    
    //result => <svg><text><tspan>Critical Surgery, Full</tspan><tspan>Health Checkup, Testing</tspan></text></svg>
    ```
- Example for array of objects:
    ```
    val vcJson = {      "credentialSubject": {          "awards": [              {"title": "Award1", "year": "2020"},              {"title": "Award2", "year": "2021"}          ]      }  }
    
    val svgTemplate = "<svg>{{/credentialSubject/awards/0/title}} - {{/credentialSubject/awards/0/year}}, {{/credentialSubject/awards/1/title}} - {{/credentialSubject/awards/1/year}}</svg>"
    
    //result => <svg>Award1 - 2020, Award2 - 2021</svg>
    ```
    
    
##### Locale Handling
- For locale handling, same JSON Pointer Algorithm is used to extract the value from the VC.
- Example:
    ```
    let vcJson = {      "credentialSubject": { "fullName": "Tester", "city": [{"value": "TestCITY", "language": "eng"},{"value": "VilleTest", "language": "fr"}]}
          
      let svgTempalte = "<svg>{{/credentialSubject/fullName}} - {{/credentialSubject/city}}</svg>"
          
      //result => <svg>Tester - TestCITY</svg>
  ```

##### Digest Multibase Validation
- If the `digestMultibase` field is present in the `template` object, it will validate the downloaded SVG Template using the digestMultibase value.
- `MultibaseValidationException` is thrown if the validation fails or digestMultibase is invalid.
- Example:
    ```
          "renderMethod": {
              "type": "TemplateRenderMethod",
              "renderSuite": "svg-mustache",
              "template": {
                      "id": "https://degree.example/credential-templates/bachelors",
                      "mediaType": "image/svg+xml",
                      "digestMultibase": "zQmerWC85Wg6wFl9znFCwYxApG270iEu5h6JqWAPdhyxz2dR"
                  }
          }
      ```
- As per spec `digestMultibase` is optional field and it should follow below standard if present.
    - An OPTIONAL multibase-encoded Multihash of the render method referenced if id is specified. The multibase value MUST be u (base64url-nopad) and the multihash value MUST be SHA-2 with 256-bits of output (0x12).


#### Replacing Placeholders in SVG Template
- Replaces the placeholders in the SVG Template with actual VC Json Data strictly follows JSON Pointer Algorithm RFC6901.
- Returns the list of replaced SVG Templates if multiple render methods are present in the VC.


### References
- [JSON Pointer Algorithm - RFC6901](https://www.rfc-editor.org/rfc/rfc6901)
- [Draft Implementation of Verifiable Credential Rendering Methods](https://w3c-ccg.github.io/vc-render-method/#the-rendermethod-property)
- [Data model 2.0 implementation](https://www.w3.org/TR/vc-data-model-2.0/#reserved-extension-points)
