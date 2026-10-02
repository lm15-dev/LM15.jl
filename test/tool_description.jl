module ToolDescriptionTests
using Test, LM15

# MAP-17: a function tool with no description reaches every wire with no description
# key, never `"description": null`. The contract's tool_no_description cases pin the
# `nothing` wire through the vet shim; these tests add what canonical JSON cannot
# carry (`""`, which serializes as absent) and the paths no case pins (a Gemini
# cached prefix, a batch body, both live setup frames).

const SCHEMA = Dict("type" => "object", "properties" => Dict("city" => Dict("type" => "string")))
weather(description) = FunctionTool(; name="get_weather", description, parameters=SCHEMA)

declarations(x, out=Any[]) = out
function declarations(x::AbstractDict, out=Any[])
    get(x, "name", nothing) == "get_weather" &&
        any(haskey(x, k) for k in ("parameters", "input_schema", "parametersJsonSchema")) &&
        push!(out, x)
    foreach(v -> declarations(v, out), values(x))
    return out
end
function declarations(x::AbstractVector, out=Any[])
    foreach(v -> declarations(v, out), x)
    return out
end
only_declaration(x) = only(declarations(x))
wire_body(req) = LM15.JSON.parse(String(copy(req.body)))

const CLIENTS = (
    "anthropic" => () -> AnthropicLM(; api_key="k", env=Dict{String,String}()),
    "openai" => () -> OpenAILM(; api_key="k", env=Dict{String,String}()),
    "openai-chat" => () -> OpenAIChatLM(; api_key="k", env=Dict{String,String}()),
    "gemini" => () -> GeminiLM(; api_key="k", env=Dict{String,String}()),
)

@testset "MAP-17: an absent or empty description is left off every dialect" begin
    for description in (nothing, ""), (provider, client) in CLIENTS
        request = Request(
            "m-1", user("hi"); tools=[weather(description)], config=Config(max_tokens=64)
        )
        decl = only_declaration(wire_body(build_request(client(), request)))
        @test !haskey(decl, "description")
        @test first(k for k in keys(decl) if k != "type") == "name"
    end
end

@testset "MAP-17: a present description keeps its slot after the name" begin
    for (provider, client) in CLIENTS
        request = Request("m-1", user("hi"); tools=[weather("Weather for a city")])
        decl = only_declaration(wire_body(build_request(client(), request)))
        names = collect(keys(decl))
        @test names[findfirst(==("name"), names) + 1] == "description"
        @test decl["description"] == "Weather for a city"
    end
end

@testset "MAP-17: live setup frames, a Gemini cached prefix and a batch leave it off" begin
    for description in (nothing, "")
        openai = OpenAILM(api_key="k", env=Dict{String,String}())
        gemini = GeminiLM(api_key="k", env=Dict{String,String}())
        for (lm, model) in
            ((openai, "gpt-realtime-mini"), (gemini, "gemini-3.1-flash-live-preview"))
            frames = LM15.live_setup_frames(lm, LiveConfig(; model, tools=[weather(description)]))
            @test !haskey(only_declaration(frames), "description")
        end
        prefix = Request(
            "gemini-2.5-flash", user("a long stable prefix"); tools=[weather(description)]
        )
        cache = LM15.build_cache_request(gemini, :create; prefix, ttl_seconds=300)
        @test !haskey(only_declaration(wire_body(cache)), "description")
        anthropic = AnthropicLM(api_key="k", env=Dict{String,String}())
        nested = Request(
            "claude-haiku-4-5",
            user("hi");
            tools=[weather(description)],
            config=Config(max_tokens=64),
        )
        batch = only(
            LM15.build_batch_requests(
                anthropic, :submit; request=BatchRequest(requests=[nested]), upload_body=nothing
            ),
        )
        @test !haskey(only_declaration(wire_body(batch)), "description")
    end
end

end
