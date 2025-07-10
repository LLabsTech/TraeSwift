import Foundation

struct ThoughtData {
    let thought: String
    let thoughtNumber: Int
    let totalThoughts: Int
    let nextThoughtNeeded: Bool
    let isRevision: Bool?
    let revisesThought: Int?
    let branchFromThought: Int?
    let branchId: String?
    let needsMoreThoughts: Bool?
}

struct SequentialThinkingArguments: Codable {
    let thought: String
    let nextThoughtNeeded: Bool
    let thoughtNumber: Int
    let totalThoughts: Int
    let isRevision: Bool?
    let revisesThought: Int?
    let branchFromThought: Int?
    let branchId: String?
    let needsMoreThoughts: Bool?
    
    enum CodingKeys: String, CodingKey {
        case thought
        case nextThoughtNeeded = "next_thought_needed"
        case thoughtNumber = "thought_number"
        case totalThoughts = "total_thoughts"
        case isRevision = "is_revision"
        case revisesThought = "revises_thought"
        case branchFromThought = "branch_from_thought"
        case branchId = "branch_id"
        case needsMoreThoughts = "needs_more_thoughts"
    }
}

final class SequentialThinkingTool: Tool, @unchecked Sendable {
    let name = "sequentialthinking"
    let description = """
    A detailed tool for dynamic and reflective problem-solving through thoughts.
    This tool helps analyze problems through a flexible thinking process that can adapt and evolve.
    Each thought can build on, question, or revise previous insights as understanding deepens.
    
    When to use this tool:
    - Breaking down complex problems into steps
    - Planning and design with room for revision
    - Analysis that might need course correction
    - Problems where the full scope might not be clear initially
    - Problems that require a multi-step solution
    - Tasks that need to maintain context over multiple steps
    - Situations where irrelevant information needs to be filtered out
    
    Key features:
    - You can adjust total_thoughts up or down as you progress
    - You can question or revise previous thoughts
    - You can add more thoughts even after reaching what seemed like the end
    - You can express uncertainty and explore alternative approaches
    - Not every thought needs to build linearly - you can branch or backtrack
    - Generates a solution hypothesis
    - Verifies the hypothesis based on the Chain of Thought steps
    - Repeats the process until satisfied
    - Provides a correct answer
    
    Parameters explained:
    - thought: Your current thinking step, which can include:
    * Regular analytical steps
    * Revisions of previous thoughts
    * Questions about previous decisions
    * Realizations about needing more analysis
    * Changes in approach
    * Hypothesis generation
    * Hypothesis verification
    - next_thought_needed: True if you need more thinking, even if at what seemed like the end
    - thought_number: Current number in sequence (can go beyond initial total if needed)
    - total_thoughts: Current estimate of thoughts needed (can be adjusted up/down)
    - is_revision: A boolean indicating if this thought revises previous thinking
    - revises_thought: If is_revision is true, which thought number is being reconsidered
    - branch_from_thought: If branching, which thought number is the branching point
    - branch_id: Identifier for the current branch (if any)
    - needs_more_thoughts: If reaching end but realizing more thoughts needed
    
    You should:
    1. Start with an initial estimate of needed thoughts, but be ready to adjust
    2. Feel free to question or revise previous thoughts
    3. Don't hesitate to add more thoughts if needed, even at the "end"
    4. Express uncertainty when present
    5. Mark thoughts that revise previous thinking or branch into new paths
    6. Ignore information that is irrelevant to the current step
    7. Generate a solution hypothesis when appropriate
    8. Verify the hypothesis based on the Chain of Thought steps
    9. Repeat the process until satisfied with the solution
    10. Provide a single, ideally correct answer as the final output
    11. Only set next_thought_needed to false when truly done and a satisfactory answer is reached
    """
    
    let parameters = JSONSchema(
        type: "object",
        properties: [
            "thought": JSONSchema.Property(
                type: "string",
                description: "Your current thinking step",
                items: nil,
                properties: nil,
                required: nil
            ),
            "next_thought_needed": JSONSchema.Property(
                type: "boolean",
                description: "Whether another thought step is needed",
                items: nil,
                properties: nil,
                required: nil
            ),
            "thought_number": JSONSchema.Property(
                type: "integer",
                description: "Current thought number. Minimum value is 1.",
                items: nil,
                properties: nil,
                required: nil
            ),
            "total_thoughts": JSONSchema.Property(
                type: "integer",
                description: "Estimated total thoughts needed. Minimum value is 1.",
                items: nil,
                properties: nil,
                required: nil
            ),
            "is_revision": JSONSchema.Property(
                type: "boolean",
                description: "Whether this revises previous thinking",
                items: nil,
                properties: nil,
                required: nil
            ),
            "revises_thought": JSONSchema.Property(
                type: "integer",
                description: "Which thought is being reconsidered. Minimum value is 1.",
                items: nil,
                properties: nil,
                required: nil
            ),
            "branch_from_thought": JSONSchema.Property(
                type: "integer",
                description: "Branching point thought number. Minimum value is 1.",
                items: nil,
                properties: nil,
                required: nil
            ),
            "branch_id": JSONSchema.Property(
                type: "string",
                description: "Branch identifier",
                items: nil,
                properties: nil,
                required: nil
            ),
            "needs_more_thoughts": JSONSchema.Property(
                type: "boolean",
                description: "If more thoughts are needed",
                items: nil,
                properties: nil,
                required: nil
            )
        ],
        required: ["thought", "next_thought_needed", "thought_number", "total_thoughts"]
    )
    
    private var thoughtHistory: [ThoughtData] = []
    private var branches: [String: [ThoughtData]] = [:]
    
    func execute(arguments: String) async throws -> String {
        // Parse JSON arguments
        guard let data = arguments.data(using: .utf8) else {
            throw ToolError.invalidArguments("Could not convert arguments to data")
        }
        
        let decoder = JSONDecoder()
        let args: SequentialThinkingArguments
        do {
            args = try decoder.decode(SequentialThinkingArguments.self, from: data)
        } catch {
            throw ToolError.invalidArguments("Invalid JSON arguments: \(error.localizedDescription)")
        }
        
        // Validate arguments
        try validateThoughtData(args)
        
        // Create thought data
        var totalThoughts = args.totalThoughts
        if args.thoughtNumber > totalThoughts {
            totalThoughts = args.thoughtNumber
        }
        
        let thoughtData = ThoughtData(
            thought: args.thought,
            thoughtNumber: args.thoughtNumber,
            totalThoughts: totalThoughts,
            nextThoughtNeeded: args.nextThoughtNeeded,
            isRevision: args.isRevision,
            revisesThought: args.revisesThought,
            branchFromThought: args.branchFromThought,
            branchId: args.branchId,
            needsMoreThoughts: args.needsMoreThoughts
        )
        
        // Add to thought history
        thoughtHistory.append(thoughtData)
        
        // Handle branching
        if thoughtData.branchFromThought != nil,
           let branchId = thoughtData.branchId {
            if branches[branchId] == nil {
                branches[branchId] = []
            }
            branches[branchId]?.append(thoughtData)
        }
        
        // Format the thought
        let formattedThought = formatThought(thoughtData)
        print(formattedThought)
        
        // Prepare response
        let responseData: [String: Any] = [
            "thought_number": thoughtData.thoughtNumber,
            "total_thoughts": thoughtData.totalThoughts,
            "next_thought_needed": thoughtData.nextThoughtNeeded,
            "branches": Array(branches.keys),
            "thought_history_length": thoughtHistory.count
        ]
        
        let responseJSON = try JSONSerialization.data(withJSONObject: responseData, options: .prettyPrinted)
        let responseString = String(data: responseJSON, encoding: .utf8) ?? "{}"
        
        return "Sequential thinking step completed.\n\nStatus:\n\(responseString)"
    }
    
    private func validateThoughtData(_ args: SequentialThinkingArguments) throws {
        if args.thought.isEmpty {
            throw ToolError.invalidArguments("Invalid thought: must be a non-empty string")
        }
        
        if args.thoughtNumber < 1 {
            throw ToolError.invalidArguments("thought_number must be at least 1")
        }
        
        if args.totalThoughts < 1 {
            throw ToolError.invalidArguments("total_thoughts must be at least 1")
        }
        
        if let revisesThought = args.revisesThought, revisesThought < 1 {
            throw ToolError.invalidArguments("revises_thought must be a positive integer")
        }
        
        if let branchFromThought = args.branchFromThought, branchFromThought < 1 {
            throw ToolError.invalidArguments("branch_from_thought must be a positive integer")
        }
    }
    
    private func formatThought(_ thoughtData: ThoughtData) -> String {
        var prefix = ""
        var context = ""
        
        if thoughtData.isRevision == true {
            prefix = "🔄 Revision"
            if let revisesThought = thoughtData.revisesThought {
                context = " (revising thought \(revisesThought))"
            }
        } else if let branchFromThought = thoughtData.branchFromThought {
            prefix = "🌿 Branch"
            let branchId = thoughtData.branchId ?? "unknown"
            context = " (from thought \(branchFromThought), ID: \(branchId))"
        } else {
            prefix = "💭 Thought"
            context = ""
        }
        
        let header = "\(prefix) \(thoughtData.thoughtNumber)/\(thoughtData.totalThoughts)\(context)"
        let borderLength = max(header.count, thoughtData.thought.count) + 4
        let border = String(repeating: "─", count: borderLength)
        
        return """
        
        ┌\(border)┐
        │ \(header.padding(toLength: borderLength - 2, withPad: " ", startingAt: 0)) │
        ├\(border)┤
        │ \(thoughtData.thought.padding(toLength: borderLength - 2, withPad: " ", startingAt: 0)) │
        └\(border)┘
        """
    }
}