# AUTH-10 backend settings (amended 2026-09-30) and MAP-7 rule 6's default max_tokens:
# lm15-contract changes/2026-09-30-claude-code-client-version.md.

const REFUSAL = "Claude Code 2.1.170 does not support this model; version 2.1.280 or newer is required. Run 'claude update', or update the Claude desktop app, then try again."

user_agent(client) = last(only(filter(h -> lowercase(first(h)) == "user-agent",
    LM15.build_request(client, Request("claude-opus-5-5", user("hi"))).headers)))

@testset "claude-code client_version is a backend setting (AUTH-10)" begin
    policy = LM15.provider_definition("claude-code").access
    @test policy.backend_options["client_version"] == "2.1.285"
    @test only(policy.backend_settings).env == ("LM15_CLAUDE_CODE_VERSION",)
    @test only(LM15.provider_definition("openai-codex").access.backend_settings).env == ("LM15_CODEX_CLIENT_VERSION",)
    @test user_agent(LM15.ProviderLM("claude-code"; api_key="k")) == "claude-cli/2.1.285"
    @test user_agent(LM15.ProviderLM("claude-code"; api_key="k", settings=Dict("client_version" => "2.1.280"))) == "claude-cli/2.1.280"
    withenv("LM15_CLAUDE_CODE_VERSION" => "9.9.9") do
        # A client built by hand reads no environment for it; a router does.
        @test user_agent(LM15.ProviderLM("claude-code"; api_key="k")) == "claude-cli/2.1.285"
    end
    @test user_agent(LM15.ProviderLM("claude-code"; api_key="k", env=Dict("LM15_CLAUDE_CODE_VERSION" => "2.1.282"))) == "claude-cli/2.1.282"
    @test user_agent(LM15.ProviderLM("claude-code"; api_key="k", env=Dict("LM15_CLAUDE_CODE_VERSION" => "2.1.282"),
        settings=Dict("client_version" => "2.1.281"))) == "claude-cli/2.1.281"
    codex = LM15.ProviderLM("openai-codex"; api_key="k", account_id="a", env=Dict("LM15_CODEX_CLIENT_VERSION" => "0.151.0"))
    @test codex.access.backend_options["client_version"] == "0.151.0"
    err = try LM15.ProviderLM("claude-code"; api_key="k", settings=Dict("version" => "1")) catch e; e end
    @test err isa NotConfiguredError && occursin("known: client_version", err.message)
    err = try LM15.ProviderLM("anthropic"; api_key="k", settings=Dict("client_version" => "1")) catch e; e end
    @test err isa NotConfiguredError && occursin("this door takes no settings", err.message)
    report = explain_auth("claude-code"; env=Dict("LM15_CLAUDE_CODE_VERSION" => "2.1.290"), claude_credentials_path="/nonexistent")
    @test report.settings == Dict("client_version" => "2.1.290")
    @test report.settings_from["client_version"].from == "env:LM15_CLAUDE_CODE_VERSION"
end

@testset "the minimum-version refusal names the setting" begin
    body = JSON.serialize(Dict("type" => "error", "request_id" => "req_1",
        "error" => Dict("type" => "invalid_request_error", "message" => REFUSAL)))
    err = LM15.normalize_error(LM15.ProviderLM("claude-code"; api_key="k"), 400, body)
    @test err isa InvalidRequestError
    @test err.message == REFUSAL * "\n\n  To fix:\n    - lm15 sends this version itself; updating Claude Code does not change it\n    - Set the claude-code setting client_version to 2.1.280 or newer (or LM15_CLAUDE_CODE_VERSION=2.1.280)\n"
    @test LM15.normalize_error(LM15.ProviderLM("anthropic"; api_key="k"), 400, body).message == REFUSAL
end

@testset "an unset max_tokens is the model's ceiling (MAP-7 rule 6)" begin
    client = LM15.ProviderLM("anthropic"; api_key="k")
    for (model, budget, wire, recorded) in (
        ("claude-opus-5-5", nothing, 128000, 128000),
        ("claude-haiku-4-5", nothing, 64000, 64000),
        ("claude-sonnet-4-5", 32768, 64000, 64000 - 32768),
        ("claude-haiku-4-5", 64000, 64000 + 16384, 16384),
        ("anthropic.claude-haiku-4-5-20251001-v1:0", nothing, 64000, 64000),
        ("claude-3-5-haiku-20241022", nothing, 8192, 8192),
        ("deepseek-v4-flash", nothing, 16384, 16384),
    )
        config = budget === nothing ? Config() : Config(; reasoning=Reasoning(; effort="high", thinking_budget=budget))
        request = Request(model, user("hi"); config)
        body = JSON.parse(String(copy(LM15.build_request(client, request).body)))
        @test body["max_tokens"] == wire
        record = only(filter(a -> a.field == "config.max_tokens", LM15.plan(client, request)))
        @test record.action == "defaulted" && record.applied == recorded
    end
end
