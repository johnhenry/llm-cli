# Bug Hunt Report - llm-cli

## Summary
This report documents bugs found during a comprehensive code review of the llm-cli repository.

**Total Bugs Found: 8**
**Total Bugs Fixed: 8**

---

## Bug #1: Missing Network Framework in Package.swift
**Severity:** 🔴 Critical (Build Failure)
**File:** `Package.swift`
**Status:** ✅ Fixed

### Description
The `Serve.swift` file imports the `Network` framework, but it was not declared in `Package.swift`, causing a build failure.

### Impact
- Application fails to build
- `llm serve` command is completely unusable

### Fix
Added the Network framework to the linker settings in Package.swift:
```swift
linkerSettings: [
    .linkedFramework("Network")
]
```

---

## Bug #2: TemplateError Protocol Conformance
**Severity:** 🟡 Medium (Incorrect Error Protocol)
**File:** `Sources/llm/Util/PromptTemplates.swift`
**Status:** ✅ Fixed

### Description
`TemplateError` was declaring `localizedDescription` as a computed property, but was not conforming to the `LocalizedError` protocol. The correct protocol property is `errorDescription`, which returns an optional String.

### Impact
- Error messages might not be displayed correctly in all contexts
- Inconsistent with Swift error handling best practices

### Fix
Changed the error to properly conform to `LocalizedError`:
```swift
enum TemplateError: Error, LocalizedError {
    case notFound(String)
    
    var errorDescription: String? {  // Changed from localizedDescription
        switch self {
        case .notFound(let name):
            return "Template '\(name)' not found in \(PromptTemplates.templatesDir.path)"
        }
    }
}
```

---

## Bug #3: Unsafe String Replacement in Template Listing
**Severity:** 🟡 Medium (Potential Data Corruption)
**File:** `Sources/llm/Util/PromptTemplates.swift`
**Status:** ✅ Fixed

### Description
The `list()` function used `replacingOccurrences(of: ".txt", with: "")` to remove the `.txt` extension. This could incorrectly remove `.txt` from the middle of filenames.

### Example Problem
A file named `my.txt.template.txt` would become `my.template` instead of `my.txt.template`.

### Impact
- Template names could be incorrectly displayed
- Could cause confusion when templates contain ".txt" in their names

### Fix
Changed to use proper suffix removal:
```swift
.map { String($0.dropLast(4)) }  // Safely removes last 4 characters (.txt)
```

---

## Bug #4: ModelSize Enum Raw Values Mismatch
**Severity:** 🔴 Critical (Feature Broken)
**File:** `Sources/llm/Models/LLM.swift`
**Status:** ✅ Fixed

### Description
The `ModelSize` enum had raw values of `"foundation-small"`, `"foundation-medium"`, and `"foundation-large"`, but all documentation and help text instructed users to use `"small"`, `"medium"`, and `"large"`.

### Impact
- Users following the documentation would get incorrect model selection
- All model arguments would silently fall back to `.medium`
- Command like `llm generate --model small` would fail to use the small model

### Examples of Broken Usage
```bash
llm generate --model small     # Would use medium (fallback)
llm chat --model large         # Would use medium (fallback)
llm serve --model small        # Would use medium (fallback)
```

### Fix
Changed enum raw values to match documentation:
```swift
enum ModelSize: String {
    case small = "small"        // Was: "foundation-small"
    case medium = "medium"      // Was: "foundation-medium"
    case large = "large"        // Was: "foundation-large"
    ...
}
```

---

## Bug #5: Force Unwrap in Network Server Setup
**Severity:** 🟡 Medium (Potential Crash)
**File:** `Sources/llm/Commands/Serve.swift`
**Status:** ✅ Fixed

### Description
The `startServer` function used a force unwrap (`!`) when creating `NWEndpoint.Port`:
```swift
let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
```

### Impact
- While `UInt16` values should generally create valid ports, force unwrapping is unsafe
- Could theoretically crash if the port creation fails
- Violates Swift safety best practices

### Fix
Added proper guard statement with error handling:
```swift
guard let nwPort = NWEndpoint.Port(rawValue: port) else {
    throw LLMError.invalidConfiguration
}
let listener = try NWListener(using: .tcp, on: nwPort)
```

---

## Bug #6: JSONDecoder Date Strategy Mismatch
**Severity:** 🟡 Medium (Data Corruption Risk)
**File:** `Sources/llm/Util/HistoryStore.swift`
**Status:** ✅ Fixed

### Description
The `HistoryStore` saves conversation history with dates encoded using `.iso8601` strategy, but loads them without setting a date decoding strategy, using the default instead. This mismatch causes saved history files to fail to load correctly.

### Impact
- Saved conversation history could not be loaded properly
- Dates would fail to decode, causing the history to be discarded
- Users would lose their conversation history silently

### Example Problem
```swift
// Saving (line 69):
encoder.dateEncodingStrategy = .iso8601  // Saves as ISO8601 format

// Loading (line 40):
JSONDecoder().decode(...)  // Uses default strategy, can't decode ISO8601!
```

### Fix
Added matching date decoding strategy:
```swift
if let data = try? Data(contentsOf: historyPath) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601  // Now matches encoding!
    if let loaded = try? decoder.decode(ConversationHistory.self, from: data) {
        self.history = loaded
    } else {
        self.history = ConversationHistory()
    }
} else {
    self.history = ConversationHistory()
}
```

---

## Bug #7: Thread Safety Violation in LLM Class
**Severity:** 🔴 Critical (Race Condition)
**File:** `Sources/llm/Models/LLM.swift`
**Status:** ✅ Fixed

### Description
The `LLM` class is marked as `@unchecked Sendable` but contains a mutable `private var customTools` array. The `registerTool()` method modifies this array without synchronization, creating a race condition when the class is used across async boundaries.

### Impact
- Potential data races when tools are registered
- Undefined behavior in concurrent contexts
- Violates Swift's Sendable contract
- Could cause crashes or data corruption

### Example Problem
```swift
final class LLM: @unchecked Sendable {
    private var customTools: [any Tool] = []  // Mutable!
    
    func registerTool(_ tool: any Tool) {
        customTools.append(tool)  // UNSAFE: No synchronization!
    }
}
```

### Fix
Made `customTools` immutable and passed tools at initialization:
```swift
final class LLM: @unchecked Sendable {
    private let customTools: [any Tool]  // Now immutable
    
    init(size: ModelSize = .medium, instructions: String? = nil, tools: [any Tool] = []) throws {
        self.size = size
        self.customTools = tools  // Set once at init
        ...
    }
    
    // Removed registerTool() method
}
```

Updated `ToolsCommand` to pass tools at initialization:
```swift
let sampleTools: [any Tool] = [
    GetCurrentTimeTool(),
    GetWeatherTool(),
    SearchFilesTool()
]
let llm = try LLM(size: modelSize, tools: sampleTools)
```

---

## Bug #8: Missing Empty Prompt Validation
**Severity:** 🟡 Medium (Poor User Experience)
**File:** `Sources/llm/Commands/Generate.swift`
**Status:** ✅ Fixed

### Description
The `generate` command doesn't validate that a prompt was provided. If a user runs `llm generate` without arguments and without piped input, the command would attempt to generate text with an empty string instead of showing an error.

### Impact
- Poor user experience
- Confusing behavior (generates nothing or errors cryptically)
- Wastes API/model resources

### Example Problem
```bash
$ llm generate
# Would try to generate with empty prompt instead of showing help
```

### Fix
Added validation before generation:
```swift
// Validate that we have a prompt
if prompt.isEmpty {
    output.printMessage("Error: No prompt provided")
    output.printMessage("Run 'llm generate --help' for usage information")
    return
}
```

---

## Additional Observations

### Potential Future Improvements (Not Bugs)
While not bugs per se, these areas could be improved:

1. **Environment Variable Validation**: `LLM_MODEL` environment variable values are not validated before use
2. **File Path Validation**: Some file operations could benefit from additional validation
3. **Error Messages**: Some error messages could be more descriptive
4. **Platform Guards**: No conditional compilation guards for macOS-specific code (though this is a macOS-only app)

### Code Quality Notes
- ✅ Good use of async/await
- ✅ Proper error handling in most places
- ✅ Clean separation of concerns with Commands/Models/Util structure
- ✅ Consistent coding style
- ✅ Good use of Swift concurrency (Actor for HistoryStore)

---

## Testing Recommendations

To verify these fixes, test the following scenarios:

1. **Build Test**: Verify the project builds successfully
2. **Model Selection**: Test `llm generate --model small/medium/large`
3. **Template Operations**: Test templates with `.txt` in their names
4. **Server Start**: Test `llm serve --port 8765`
5. **Error Messages**: Verify error messages display correctly
6. **History Persistence**: Test saving and loading conversation history with dates
7. **Tools**: Test `llm tools --list` and `llm tools --demo`
8. **Empty Prompt**: Test `llm generate` with no arguments

---

## Conclusion

All identified bugs have been fixed. The changes are minimal and focused on the specific issues without altering the overall architecture or functionality of the application. The fixes improve:
- Build reliability (Bug #1)
- Error handling consistency (Bug #2, #5, #8)
- Data integrity (Bug #3, #6)
- User experience (Bug #4, #8)
- Thread safety (Bug #7)

**Report Generated:** 2025-10-12
**Reviewed By:** GitHub Copilot
**Updated:** 2025-10-12 (Added bugs #6, #7, #8)
