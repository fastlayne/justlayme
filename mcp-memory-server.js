#!/usr/bin/env node

/**
 * JustLayMe MCP Memory Server
 * Provides persistent memory for tracking project progress and conversations
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const fs = require('fs').promises;
const path = require('path');

class MemoryServer {
    constructor() {
        this.server = new Server(
            {
                name: "justlayme-memory",
                version: "1.0.0"
            },
            {
                capabilities: {
                    resources: {},
                    tools: {}
                }
            }
        );

        this.memoryFile = path.join(__dirname, 'project-memory.json');
        this.setupHandlers();
    }

    async loadMemory() {
        try {
            const data = await fs.readFile(this.memoryFile, 'utf8');
            return JSON.parse(data);
        } catch (error) {
            return {
                sessions: [],
                project_state: {},
                todos: [],
                knowledge_graph: {},
                created_at: new Date().toISOString()
            };
        }
    }

    async saveMemory(memory) {
        await fs.writeFile(this.memoryFile, JSON.stringify(memory, null, 2));
    }

    setupHandlers() {
        // List available tools
        this.server.setRequestHandler('tools/list', async () => {
            return {
                tools: [
                    {
                        name: "add_conversation_memory",
                        description: "Add a conversation or session to memory",
                        inputSchema: {
                            type: "object",
                            properties: {
                                session_id: { type: "string" },
                                summary: { type: "string" },
                                accomplishments: { type: "array", items: { type: "string" } },
                                problems_solved: { type: "array", items: { type: "string" } },
                                next_steps: { type: "array", items: { type: "string" } },
                                files_created: { type: "array", items: { type: "string" } },
                                technologies: { type: "array", items: { type: "string" } }
                            },
                            required: ["session_id", "summary"]
                        }
                    },
                    {
                        name: "update_project_state",
                        description: "Update the current state of the project",
                        inputSchema: {
                            type: "object",
                            properties: {
                                feature: { type: "string" },
                                status: { type: "string", enum: ["planned", "in_progress", "completed", "blocked"] },
                                details: { type: "string" },
                                files_affected: { type: "array", items: { type: "string" } }
                            },
                            required: ["feature", "status"]
                        }
                    },
                    {
                        name: "add_todo",
                        description: "Add a todo item to track",
                        inputSchema: {
                            type: "object",
                            properties: {
                                task: { type: "string" },
                                priority: { type: "string", enum: ["low", "medium", "high", "critical"] },
                                category: { type: "string" },
                                estimated_time: { type: "string" },
                                dependencies: { type: "array", items: { type: "string" } }
                            },
                            required: ["task", "priority"]
                        }
                    },
                    {
                        name: "update_todo",
                        description: "Update a todo item status",
                        inputSchema: {
                            type: "object",
                            properties: {
                                todo_id: { type: "string" },
                                status: { type: "string", enum: ["pending", "in_progress", "completed", "blocked"] },
                                notes: { type: "string" }
                            },
                            required: ["todo_id", "status"]
                        }
                    },
                    {
                        name: "query_memory",
                        description: "Query the memory for specific information",
                        inputSchema: {
                            type: "object",
                            properties: {
                                query: { type: "string" },
                                category: { type: "string", enum: ["sessions", "todos", "project_state", "all"] }
                            },
                            required: ["query"]
                        }
                    },
                    {
                        name: "get_project_status",
                        description: "Get complete project status and progress",
                        inputSchema: {
                            type: "object",
                            properties: {}
                        }
                    }
                ]
            };
        });

        // Handle tool calls
        this.server.setRequestHandler('tools/call', async (request) => {
            const { name, arguments: args } = request.params;

            switch (name) {
                case "add_conversation_memory":
                    return await this.addConversationMemory(args);
                case "update_project_state":
                    return await this.updateProjectState(args);
                case "add_todo":
                    return await this.addTodo(args);
                case "update_todo":
                    return await this.updateTodo(args);
                case "query_memory":
                    return await this.queryMemory(args);
                case "get_project_status":
                    return await this.getProjectStatus();
                default:
                    throw new Error(`Unknown tool: ${name}`);
            }
        });
    }

    async addConversationMemory(args) {
        const memory = await this.loadMemory();
        
        const session = {
            id: args.session_id,
            timestamp: new Date().toISOString(),
            summary: args.summary,
            accomplishments: args.accomplishments || [],
            problems_solved: args.problems_solved || [],
            next_steps: args.next_steps || [],
            files_created: args.files_created || [],
            technologies: args.technologies || []
        };

        memory.sessions.push(session);
        await this.saveMemory(memory);

        return {
            content: [
                {
                    type: "text",
                    text: `Added conversation memory for session ${args.session_id}. Total sessions: ${memory.sessions.length}`
                }
            ]
        };
    }

    async updateProjectState(args) {
        const memory = await this.loadMemory();
        
        if (!memory.project_state[args.feature]) {
            memory.project_state[args.feature] = {};
        }

        memory.project_state[args.feature] = {
            status: args.status,
            details: args.details || "",
            files_affected: args.files_affected || [],
            last_updated: new Date().toISOString()
        };

        await this.saveMemory(memory);

        return {
            content: [
                {
                    type: "text",
                    text: `Updated project state for ${args.feature}: ${args.status}`
                }
            ]
        };
    }

    async addTodo(args) {
        const memory = await this.loadMemory();
        
        const todo = {
            id: `todo_${Date.now()}`,
            task: args.task,
            priority: args.priority,
            category: args.category || "general",
            status: "pending",
            estimated_time: args.estimated_time,
            dependencies: args.dependencies || [],
            created_at: new Date().toISOString()
        };

        memory.todos.push(todo);
        await this.saveMemory(memory);

        return {
            content: [
                {
                    type: "text",
                    text: `Added todo: ${args.task} (Priority: ${args.priority}, ID: ${todo.id})`
                }
            ]
        };
    }

    async updateTodo(args) {
        const memory = await this.loadMemory();
        
        const todo = memory.todos.find(t => t.id === args.todo_id);
        if (!todo) {
            throw new Error(`Todo not found: ${args.todo_id}`);
        }

        todo.status = args.status;
        todo.notes = args.notes || todo.notes;
        todo.updated_at = new Date().toISOString();

        if (args.status === "completed") {
            todo.completed_at = new Date().toISOString();
        }

        await this.saveMemory(memory);

        return {
            content: [
                {
                    type: "text",
                    text: `Updated todo ${args.todo_id}: ${todo.task} -> ${args.status}`
                }
            ]
        };
    }

    async queryMemory(args) {
        const memory = await this.loadMemory();
        const query = args.query.toLowerCase();
        let results = [];

        if (!args.category || args.category === "sessions" || args.category === "all") {
            const sessionResults = memory.sessions.filter(session => 
                session.summary.toLowerCase().includes(query) ||
                session.accomplishments.some(acc => acc.toLowerCase().includes(query)) ||
                session.problems_solved.some(prob => prob.toLowerCase().includes(query))
            );
            results.push(...sessionResults.map(s => ({ type: "session", data: s })));
        }

        if (!args.category || args.category === "todos" || args.category === "all") {
            const todoResults = memory.todos.filter(todo =>
                todo.task.toLowerCase().includes(query) ||
                todo.category.toLowerCase().includes(query)
            );
            results.push(...todoResults.map(t => ({ type: "todo", data: t })));
        }

        if (!args.category || args.category === "project_state" || args.category === "all") {
            const stateResults = Object.entries(memory.project_state).filter(([feature, state]) =>
                feature.toLowerCase().includes(query) ||
                state.details.toLowerCase().includes(query)
            );
            results.push(...stateResults.map(([feature, state]) => ({ type: "project_state", feature, data: state })));
        }

        return {
            content: [
                {
                    type: "text",
                    text: `Found ${results.length} results for "${args.query}":\n\n${JSON.stringify(results, null, 2)}`
                }
            ]
        };
    }

    async getProjectStatus() {
        const memory = await this.loadMemory();
        
        const status = {
            total_sessions: memory.sessions.length,
            latest_session: memory.sessions[memory.sessions.length - 1]?.timestamp,
            total_todos: memory.todos.length,
            pending_todos: memory.todos.filter(t => t.status === "pending").length,
            in_progress_todos: memory.todos.filter(t => t.status === "in_progress").length,
            completed_todos: memory.todos.filter(t => t.status === "completed").length,
            project_features: Object.keys(memory.project_state).length,
            completed_features: Object.values(memory.project_state).filter(s => s.status === "completed").length,
            in_progress_features: Object.values(memory.project_state).filter(s => s.status === "in_progress").length
        };

        return {
            content: [
                {
                    type: "text",
                    text: `Project Status Report:\n\n${JSON.stringify(status, null, 2)}\n\nRecent Activity:\n${JSON.stringify(memory.sessions.slice(-3), null, 2)}`
                }
            ]
        };
    }

    async run() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.error("JustLayMe Memory Server running...");
    }
}

if (require.main === module) {
    const server = new MemoryServer();
    server.run().catch(console.error);
}

module.exports = MemoryServer;