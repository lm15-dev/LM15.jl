module AuthFailedTests
using Test, LanguageModel15
using LanguageModel15: JSON

# MAP-18 (lm15-contract spec/auth-failed.json, 2026-10-10): a provider's "this
# key is not valid" is AuthError whatever the status; AUTH-1/AUTH-5 (amended
# 2026-10-10): a key put where a cloud identity name goes is never repeated.

const SENTINEL = "SECRET-SENTINEL-DO-NOT-PRINT"
const SPEC = joinpath(get(ENV, "LM15_CONTRACT_DIR", joinpath(@__DIR__, "..", "..", "lm15-contract")), "spec", "auth-failed.json")

@testset "MAP-18 forms are the contract's" begin
    if isfile(SPEC)
        pinned = JSON.parse(read(SPEC, String))["forms"]
        ours = JSON.parse(read(joinpath(pkgdir(LanguageModel15), "src", "data", "auth_failed.json"), String))
        @test ours == pinned
    end
    help = Dict("details" => Any[Dict("@type" => "type.googleapis.com/google.rpc.Help", "reason" => "API_KEY_INVALID")])
    @test isempty(LanguageModel15.google_error_reasons(help))
    @test !LanguageModel15.pinned_auth_failure("INVALID_ARGUMENT", "API key not valid.", LanguageModel15.google_error_reasons(help))
end

@testset "a key given as a named credential is never shown" begin
    for make in (() -> AnthropicLM(; credential=SENTINEL), () -> GeminiLM(; credential=SENTINEL))
        err = try
            make(); nothing
        catch e
            e
        end
        @test err isa NotConfiguredError
        @test !occursin(SENTINEL, sprint(showerror, err))
        @test !occursin(SENTINEL, repr(err))
        @test occursin("may be a key", sprint(showerror, err))
    end
end
end
