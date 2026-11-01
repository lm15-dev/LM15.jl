# AUTH-15: a saved cloud recipe's settings build the managed route; an explicit
# settings entry refines them setting by setting (lm15-contract
# changes/2026-10-15-saved-cloud-settings.md).

@testset "a saved cloud recipe's settings build the managed route (AUTH-15)" begin
    auth = LanguageModel15.memory_auth()
    LanguageModel15.configure(auth, "vertex-anthropic"; method="cloud", answers=Dict("named" => "environment"),
        settings=Dict("project" => "saved-project", "location" => "us-east5"))
    env = Dict("NO_GCE_CHECK" => "1", "GOOGLE_CLOUD_PROJECT" => "env-project")
    built(; kw...) = let s = LanguageModel15.lm(LanguageModel15.LMRouter(LanguageModel15.RouterConfig(; env, auth, kw...)), "vertex-anthropic:claude-test").settings
        (s["project"], s["location"])
    end
    @test built() == ("saved-project", "us-east5")
    @test built(settings=Dict("vertex_anthropic" => Dict("project" => "explicit-project"))) == ("explicit-project", "us-east5")
    # An explicit key selects no connection: its settings do not apply.
    @test built(api_keys=Dict("vertex-anthropic" => "explicit-key"),
        settings=Dict("vertex-anthropic" => Dict("location" => "europe-west1"))) == ("env-project", "europe-west1")
end
