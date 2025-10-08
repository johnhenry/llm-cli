import Foundation
import FoundationModels

struct ToolsCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var shouldList = false
        var shouldDemo = false
        var shouldInteractive = false
        var modelSize: ModelSize = .medium

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--list", "-l":
                shouldList = true
            case "--demo", "-d":
                shouldDemo = true
            case "--interactive", "-i":
                shouldInteractive = true
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            default:
                break
            }
            i += 1
        }

        do {
            let llm = try LLM(size: modelSize)

            // Register sample tools
            registerSampleTools(llm: llm)

            if shouldList {
                listTools(llm: llm, output: output)
            } else if shouldDemo {
                await demoTools(output: output)
            } else if shouldInteractive {
                await interactiveDemo(llm: llm, output: output)
            } else {
                printUsage()
            }

        } catch {
            output.printError(error)
        }
    }

    private static func registerSampleTools(llm: LLM) {
        llm.registerTool(GetCurrentTimeTool())
        llm.registerTool(GetWeatherTool())
        llm.registerTool(SearchFilesTool())
    }

    private static func listTools(llm: LLM, output: OutputHandler) {
        output.printMessage("🔧 Registered Tools:\n")

        let tools = llm.getTools()
        if tools.isEmpty {
            output.printMessage("No tools registered.")
            return
        }

        for (index, tool) in tools.enumerated() {
            output.printMessage("\(index + 1). \(tool.name)")
            output.printMessage("   \(tool.description)")
            output.printMessage("")
        }
    }

    private static func demoTools(output: OutputHandler) async {
        output.printMessage("🔧 Tools Demo\n")
        output.printMessage("Demonstrating tool execution...\n")

        // Demo GetCurrentTimeTool
        do {
            let timeTool = GetCurrentTimeTool()
            output.printMessage("Tool: \(timeTool.name)")
            output.printMessage("Description: \(timeTool.description)")
            let result = try await timeTool.call(arguments: GetCurrentTimeTool.Arguments())
            // GeneratedContent can be converted to String or use description
            output.printMessage("Result: \(String(describing: result))")
            output.printMessage("")
        } catch {
            output.printMessage("Error: \(error.localizedDescription)\n")
        }

        // Demo GetWeatherTool
        do {
            let weatherTool = GetWeatherTool()
            output.printMessage("Tool: \(weatherTool.name)")
            output.printMessage("Description: \(weatherTool.description)")
            let result = try await weatherTool.call(arguments: GetWeatherTool.Arguments(location: "San Francisco"))
            output.printMessage("Result: \(String(describing: result))")
            output.printMessage("")
        } catch {
            output.printMessage("Error: \(error.localizedDescription)\n")
        }

        // Demo SearchFilesTool
        do {
            let searchTool = SearchFilesTool()
            output.printMessage("Tool: \(searchTool.name)")
            output.printMessage("Description: \(searchTool.description)")
            let result = try await searchTool.call(arguments: SearchFilesTool.Arguments(pattern: ".swift"))
            output.printMessage("Result: \(String(describing: result))")
            output.printMessage("")
        } catch {
            output.printMessage("Error: \(error.localizedDescription)\n")
        }
    }

    private static func interactiveDemo(llm: LLM, output: OutputHandler) async {
        output.printMessage("🔧 Interactive Tool Demo\n")
        output.printMessage("Ask the model to use tools. Type 'exit' to quit.\n")
        output.printMessage("Example: 'What time is it?'\n")

        while true {
            print("You: ", terminator: "")
            guard let userInput = readLine(), !userInput.isEmpty else {
                continue
            }

            let trimmed = userInput.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed == "exit" || trimmed == "quit" {
                output.printMessage("\n👋 Goodbye!")
                break
            }

            do {
                print("Assistant: ", terminator: "")
                for try await token in llm.streamText(from: userInput) {
                    print(token, terminator: "")
                    fflush(stdout)
                }
                print("\n")
            } catch {
                output.printMessage("Error: \(error.localizedDescription)\n")
            }
        }
    }

    static func printUsage() {
        print("""
        Usage: llm tools [options]

        Options:
          --list, -l            List all registered tools
          --demo, -d            Demonstrate tool execution
          --interactive, -i     Interactive tool demo with the model
          --model, -m <size>    Model size (small, medium, large)

        Examples:
          llm tools --list
          llm tools --demo
          llm tools --interactive
        """)
    }
}
